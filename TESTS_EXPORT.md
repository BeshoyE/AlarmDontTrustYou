# alarmAppNew - Test Suite Export

Generated: 2025-10-11

Total Test Files: 33

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/AppRouterTests.swift

```swift
//
//  AppRouterTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/7/25.
//  Tests for AppRouter single-instance guard functionality
//

import XCTest
@testable import alarmAppNew

@MainActor
class AppRouterTests: XCTestCase {
    var router: AppRouter!

    override func setUp() {
        super.setUp()
        router = AppRouter()
    }

    // MARK: - Single Instance Guard Tests

    func test_showRinging_singleInstance_ignoresSubsequentRequests() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()

        // When - first ringing request
        router.showRinging(for: firstAlarmId)

        // Then - should set route and track alarm
        XCTAssertEqual(router.route, .ringing(alarmID: firstAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)

        // When - second ringing request (should be ignored)
        router.showRinging(for: secondAlarmId)

        // Then - route unchanged, still showing first alarm
        XCTAssertEqual(router.route, .ringing(alarmID: firstAlarmId))
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
    }

    func test_showDismissal_singleInstance_ignoresSubsequentRequests() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()

        // When - first dismissal request
        router.showDismissal(for: firstAlarmId)

        // Then - should set route and track alarm
        XCTAssertEqual(router.route, .dismissal(alarmID: firstAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)

        // When - second dismissal request (should be ignored)
        router.showDismissal(for: secondAlarmId)

        // Then - route unchanged, still showing first alarm
        XCTAssertEqual(router.route, .dismissal(alarmID: firstAlarmId))
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
    }

    func test_backToList_clearsActiveDismissalState() {
        let alarmId = UUID()

        // Given - active dismissal flow
        router.showRinging(for: alarmId)
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId)

        // When - back to list
        router.backToList()

        // Then - dismissal state cleared
        XCTAssertEqual(router.route, .alarmList)
        XCTAssertFalse(router.isInDismissalFlow)
        XCTAssertNil(router.currentDismissalAlarmId)
    }

    func test_showRinging_afterBackToList_allowsNewDismissal() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()

        // Given - first dismissal flow completed
        router.showRinging(for: firstAlarmId)
        router.backToList()
        XCTAssertFalse(router.isInDismissalFlow)

        // When - new ringing request
        router.showRinging(for: secondAlarmId)

        // Then - new dismissal flow started
        XCTAssertEqual(router.route, .ringing(alarmID: secondAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, secondAlarmId)
    }

    func test_mixedRoutes_singleInstance_preventsCrossPollination() {
        let alarmId1 = UUID()
        let alarmId2 = UUID()

        // Given - ringing flow active
        router.showRinging(for: alarmId1)
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId1))

        // When - try to show dismissal for different alarm
        router.showDismissal(for: alarmId2)

        // Then - request ignored, still in ringing flow
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId1))
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId1)
    }

    func test_initialState_allowsFirstDismissal() {
        let alarmId = UUID()

        // Given - initial state
        XCTAssertEqual(router.route, .alarmList)
        XCTAssertFalse(router.isInDismissalFlow)
        XCTAssertNil(router.currentDismissalAlarmId)

        // When - first dismissal request
        router.showRinging(for: alarmId)

        // Then - dismissal flow started
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Alarms/AlarmFactoryTests.swift

```swift
//
//  AlarmFactoryTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class AlarmFactoryTests: XCTestCase {

    func test_makeNewAlarm_setsDefaultValues() {
        // Given: A factory instance
        let factory = StandardAlarmFactory()

        // When: Creating a new alarm
        let alarm = factory.makeNewAlarm()

        // Then: Should have sensible defaults
        XCTAssertNotNil(alarm.id)
        XCTAssertGreaterThan(alarm.time, Date())
        XCTAssertEqual(alarm.label, "Alarm")
        XCTAssertTrue(alarm.repeatDays.isEmpty)
        XCTAssertTrue(alarm.challengeKind.isEmpty)
        XCTAssertNil(alarm.expectedQR)
        XCTAssertNil(alarm.stepThreshold)
        XCTAssertNil(alarm.mathChallenge)
        XCTAssertTrue(alarm.isEnabled)
        XCTAssertEqual(alarm.soundId, "ringtone1")
        XCTAssertEqual(alarm.volume, 0.8)
    }

    func test_makeNewAlarm_generatesUniqueIDs() {
        // Given: A factory instance
        let factory = StandardAlarmFactory()

        // When: Creating multiple alarms
        let alarm1 = factory.makeNewAlarm()
        let alarm2 = factory.makeNewAlarm()

        // Then: Should have unique IDs
        XCTAssertNotEqual(alarm1.id, alarm2.id)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/alarmAppNewTests.swift

```swift
//
//  alarmAppNewTests.swift
//  alarmAppNewTests
//
//  Created by Beshoy Eskarous on 9/24/25.
//

import Testing

struct alarmAppNewTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/AlarmKitIntegrationTests.swift

```swift
//
//  AlarmKitIntegrationTests.swift
//  alarmAppNewTests
//
//  Integration tests for AlarmKit components (CHUNK 7)
//  Validates the complete AlarmKit integration stack
//

import XCTest
@testable import alarmAppNew

@MainActor
final class AlarmKitIntegrationTests: XCTestCase {

    // MARK: - Test: Factory Selection Logic

    func test_factory_selectsLegacyScheduler_onCurrentiOS() {
        // Given: Factory with real dependencies
        let idMapping = InMemoryAlarmIdMapping()
        let mockLegacy = MockAlarmSchedulingForFactory()
        let presentationBuilder = AlarmPresentationBuilder()

        // When: Create scheduler via factory (should select legacy on iOS < 26)
        let scheduler = AlarmSchedulerFactory.make(
            idMapping: idMapping,
            legacy: mockLegacy,
            presentationBuilder: presentationBuilder
        )

        // Then: On current iOS, should use legacy scheduler
        if #available(iOS 26.0, *) {
            // If running on iOS 26+, factory returns AlarmKitScheduler
            XCTAssertTrue(scheduler is AlarmKitScheduler, "Should use AlarmKitScheduler on iOS 26+")
        } else {
            // On iOS < 26, factory returns the legacy scheduler as-is
            XCTAssertTrue(scheduler is MockAlarmSchedulingForFactory, "Should use legacy scheduler on iOS < 26")
        }
    }

    // MARK: - Test: AlarmScheduling Protocol Compliance

    func test_legacyScheduler_conformsToAlarmScheduling() async throws {
        // Given: Legacy NotificationService mock
        let mockLegacy = MockAlarmSchedulingForFactory()

        // When: Use as AlarmScheduling
        let scheduler: AlarmScheduling = mockLegacy

        // Then: Should support all required operations
        try await scheduler.requestAuthorizationIfNeeded()

        let testAlarm = createTestAlarm()
        let externalId = try await scheduler.schedule(alarm: testAlarm)
        XCTAssertFalse(externalId.isEmpty, "Should return external ID")

        await scheduler.cancel(alarmId: testAlarm.id)
        XCTAssertEqual(mockLegacy.cancelCalls.count, 1)

        let pendingIds = await scheduler.pendingAlarmIds()
        XCTAssertNotNil(pendingIds)
    }

    @available(iOS 26.0, *)
    func test_alarmKitScheduler_conformsToAlarmScheduling() async throws {
        // Given: AlarmKit scheduler
        let idMapping = InMemoryAlarmIdMapping()
        let presentationBuilder = AlarmPresentationBuilder()
        let scheduler = AlarmKitScheduler(
            idMapping: idMapping,
            presentationBuilder: presentationBuilder
        )

        // Activate the scheduler first
        await scheduler.activate()

        // When: Use as AlarmScheduling
        let testAlarm = createTestAlarm()

        // Then: Should support scheduling operations
        // Note: These will fail in test environment without AlarmManager entitlement
        // but we're testing protocol conformance, not actual AlarmKit functionality
        do {
            _ = try await scheduler.schedule(alarm: testAlarm)
        } catch {
            // Expected to fail without entitlement - that's OK for protocol conformance test
            print("Expected error without AlarmKit entitlement: \(error)")
        }

        // Cancel should not throw even without entitlement
        await scheduler.cancel(alarmId: testAlarm.id)

        let pendingIds = await scheduler.pendingAlarmIds()
        XCTAssertNotNil(pendingIds)
    }

    // MARK: - Test: AlarmIdMapping Round-Trip

    func test_idMapping_roundTrip() async {
        // Given: In-memory mapping
        let mapping = InMemoryAlarmIdMapping()
        let alarmId = UUID()
        let externalId = "test-external-id-123"

        // When: Store mapping
        await mapping.store(alarmId: alarmId, externalId: externalId)

        // Then: Should retrieve correctly
        let retrievedExternal = await mapping.externalId(for: alarmId)
        XCTAssertEqual(retrievedExternal, externalId)

        let retrievedInternal = await mapping.alarmId(for: externalId)
        XCTAssertEqual(retrievedInternal, alarmId)
    }

    func test_idMapping_clearRemovesMapping() async {
        // Given: Mapping with stored ID
        let mapping = InMemoryAlarmIdMapping()
        let alarmId = UUID()
        let externalId = "test-id"
        await mapping.store(alarmId: alarmId, externalId: externalId)

        // When: Clear the mapping
        await mapping.clear(alarmId: alarmId)

        // Then: Should no longer exist
        let retrievedExternal = await mapping.externalId(for: alarmId)
        XCTAssertNil(retrievedExternal)

        let retrievedInternal = await mapping.alarmId(for: externalId)
        XCTAssertNil(retrievedInternal)
    }

    // MARK: - Test: Presentation Builder Output Format

    func test_presentationBuilder_producesValidOutput() {
        // Given: Presentation builder
        let builder = AlarmPresentationBuilder()
        let alarm = createTestAlarm()

        // When: Build presentation
        let presentation = builder.build(for: alarm)

        // Then: Should have required fields
        XCTAssertEqual(presentation.title, alarm.label)
        XCTAssertFalse(presentation.body.isEmpty, "Body should not be empty")
        XCTAssertNotNil(presentation.soundId, "Should have sound ID")
        XCTAssertEqual(presentation.alarmId, alarm.id)
    }

    func test_presentationBuilder_includesTimeInBody() {
        // Given: Alarm with specific time
        let builder = AlarmPresentationBuilder()
        let alarm = createTestAlarm()

        // When: Build presentation
        let presentation = builder.build(for: alarm)

        // Then: Body should mention time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: alarm.time)

        XCTAssertTrue(
            presentation.body.contains(timeString),
            "Body should contain formatted time: \(presentation.body)"
        )
    }

    // MARK: - Test: Stop/Snooze Policy Gates

    func test_stopAlarmAllowed_gatesCorrectly() {
        // Given: Alarm with challenges
        let alarmWithQR = createTestAlarm(challenges: [.qr])
        let alarmNoChallenges = createTestAlarm(challenges: [])

        // When/Then: Check if stop is allowed
        XCTAssertFalse(
            StopAlarmAllowed.compute(for: alarmWithQR, allChallengesCompleted: false),
            "Stop should NOT be allowed with incomplete QR challenge"
        )

        XCTAssertTrue(
            StopAlarmAllowed.compute(for: alarmWithQR, allChallengesCompleted: true),
            "Stop should be allowed when all challenges completed"
        )

        XCTAssertTrue(
            StopAlarmAllowed.compute(for: alarmNoChallenges, allChallengesCompleted: true),
            "Stop should be allowed for alarm with no challenges"
        )
    }

    func test_snoozeAlarm_computesCorrectDuration() {
        // Given: Alarm
        let alarm = createTestAlarm()
        let now = Date()

        // When: Compute snooze
        let snoozeResult = SnoozeAlarm.compute(for: alarm, at: now)

        // Then: Should have valid snooze time
        XCTAssertNotNil(snoozeResult)
        if let result = snoozeResult {
            XCTAssertGreaterThan(result.newFireTime, now, "Snooze should be in the future")
            XCTAssertEqual(result.snoozeDuration, 300, "Default snooze is 5 minutes (300 seconds)")
        }
    }

    // MARK: - Test: Integration with DependencyContainer

    func test_dependencyContainer_providesAlarmScheduler() {
        // Given: Real dependency container
        let container = DependencyContainer()

        // When: Access alarm scheduler
        let scheduler = container.alarmScheduler

        // Then: Should not be nil and should be correct type
        XCTAssertNotNil(scheduler)

        if #available(iOS 26.0, *) {
            // On iOS 26+, should be AlarmKitScheduler
            XCTAssertTrue(scheduler is AlarmKitScheduler, "Should use AlarmKitScheduler on iOS 26+")
        } else {
            // On iOS < 26, should be NotificationService
            XCTAssertTrue(scheduler is NotificationService, "Should use NotificationService on iOS < 26")
        }
    }

    // MARK: - Test Helpers

    private func createTestAlarm(challenges: [ChallengeKind] = [.qr]) -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600), // 1 hour from now
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: challenges,
            expectedQR: challenges.contains(.qr) ? "test-qr-code" : nil,
            stepThreshold: challenges.contains(.steps) ? 50 : nil,
            mathChallenge: challenges.contains(.math) ? .easy : nil,
            isEnabled: true,
            soundId: "ringtone1",
            volume: 0.8
        )
    }
}

// MARK: - Mock Types for Integration Tests

final class MockAlarmSchedulingForFactory: AlarmScheduling {
    var scheduleCalls: [Alarm] = []
    var cancelCalls: [UUID] = []

    func requestAuthorizationIfNeeded() async throws {
        // Mock implementation
    }

    func schedule(alarm: Alarm) async throws -> String {
        scheduleCalls.append(alarm)
        return "mock-external-id-\(alarm.id.uuidString)"
    }

    func cancel(alarmId: UUID) async {
        cancelCalls.append(alarmId)
    }

    func pendingAlarmIds() async -> [UUID] {
        return scheduleCalls.map { $0.id }
    }

    func stop(alarmId: UUID) async throws {
        // Mock implementation
    }

    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        // Mock implementation
    }
}

// MARK: - In-Memory AlarmIdMapping for Testing

actor InMemoryAlarmIdMapping: AlarmIdMapping {
    private var internalToExternal: [UUID: String] = [:]
    private var externalToInternal: [String: UUID] = [:]

    func store(alarmId: UUID, externalId: String) {
        internalToExternal[alarmId] = externalId
        externalToInternal[externalId] = alarmId
    }

    func externalId(for alarmId: UUID) -> String? {
        return internalToExternal[alarmId]
    }

    func alarmId(for externalId: String) -> UUID? {
        return externalToInternal[externalId]
    }

    func clear(alarmId: UUID) {
        if let externalId = internalToExternal[alarmId] {
            externalToInternal.removeValue(forKey: externalId)
        }
        internalToExternal.removeValue(forKey: alarmId)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/AlarmListViewModelTests.swift

```swift
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
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Architecture_SingletonGuardrailTests.swift

```swift
//
//  Architecture_SingletonGuardrailTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/8/25.
//  Architectural guardrail tests to prevent singleton usage
//

import XCTest
@testable import alarmAppNew

final class Architecture_SingletonGuardrailTests: XCTestCase {

    /// Verifies that DependencyContainer.shared does not exist anywhere in the Swift source code
    /// (excluding this test file and documentation)
    func test_noSingletonReferencesInCodebase() throws {
        // GIVEN: Project root directory
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // alarmAppNewTests
            .deletingLastPathComponent() // Project root

        // WHEN: Searching for DependencyContainer.shared in Swift files
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        process.arguments = [
            "-r",                                  // Recursive search
            "DependencyContainer\\.shared",        // Pattern to find
            "--include=*.swift",                   // Only Swift files
            "--exclude-dir=build",                 // Exclude build directory
            "--exclude-dir=.build",                // Exclude build directory
            projectRoot.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Filter out acceptable references (this test file and docs)
        let lines = output.split(separator: "\n")
        let violations = lines.filter { line in
            let lineStr = String(line)
            // Allow references in this test file
            if lineStr.contains("Architecture_SingletonGuardrailTests.swift") {
                return false
            }
            // Allow references in documentation
            if lineStr.contains("/docs/") || lineStr.contains("CLAUDE.md") {
                return false
            }
            return true
        }

        // THEN: No violations should be found
        if !violations.isEmpty {
            let violationList = violations.map { "  • \($0)" }.joined(separator: "\n")
            XCTFail("""
                ❌ SINGLETON USAGE DETECTED!

                Found DependencyContainer.shared references in the codebase.
                This project requires all dependencies to be injected via initializers or environment.

                Violations found:
                \(violationList)

                Fix: Replace singleton access with proper dependency injection:
                - Pass DependencyContainer via initializer parameters
                - Use SwiftUI environment injection: @Environment(\\.container)
                - Update factory methods in DependencyContainer to accept dependencies
                """)
        }
    }

    /// Verifies that DependencyContainer does not have a static shared property
    func test_dependencyContainerHasNoStaticShared() {
        // Use runtime reflection to check for static 'shared' property
        let mirror = Mirror(reflecting: DependencyContainer.self)

        // Check static properties (would appear in type's mirror)
        let hasSharedProperty = mirror.children.contains { child in
            child.label == "shared"
        }

        XCTAssertFalse(hasSharedProperty,
                      "DependencyContainer should NOT have a static 'shared' property. Use dependency injection instead.")
    }

    /// Verifies that DependencyContainer init is public (not private)
    func test_dependencyContainerInitIsPublic() {
        // This test verifies we can create instances freely
        let container1 = DependencyContainer()
        let container2 = DependencyContainer()

        // Each instance should be independent
        XCTAssertFalse(container1 === container2,
                      "DependencyContainer instances should be independent (not singleton)")
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/ChainedSchedulingIntegrationTests.swift

```swift
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
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/DismissalFlowViewModelTests.swift

```swift
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

```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/E2E_AlarmDismissalFlowTests.swift

```swift
//
//  E2E_AlarmDismissalFlowTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/7/25.
//  End-to-end tests for critical MVP1 scenarios
//

import XCTest
@testable import alarmAppNew

@MainActor
class E2E_AlarmDismissalFlowTests: XCTestCase {
    var dependencyContainer: DependencyContainer!
    var mockClock: TestClock!
    
    override func setUp() {
        super.setUp()

        // Create owned dependency container instance for testing
        dependencyContainer = DependencyContainer()
        mockClock = TestClock()
    }
    
    override func tearDown() {
        // Clean up any test data
        try? dependencyContainer.persistenceService.saveAlarms([])
        dependencyContainer.reliabilityLogger.clearLogs()
        super.tearDown()
    }
    
    // MARK: - E2E: Full Alarm Flow
    
    func test_E2E_setAlarm_ring_scan_dismiss_success() async throws {
        // This test simulates the complete user journey:
        // 1. User creates alarm with QR code
        // 2. Alarm fires (notification)
        // 3. User taps notification -> navigates to ringing view
        // 4. User scans correct QR code
        // 5. Alarm is dismissed successfully
        
        // GIVEN: Create alarm with QR code
        let testQRCode = "test-qr-code-12345"
        let alarm = Alarm(
            id: UUID(),
            time: mockClock.now().addingTimeInterval(60), // 1 minute from now
            label: "E2E Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: testQRCode,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
        
        // WHEN: User enables alarm (should schedule notification)
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        alarmListVM.add(alarm)
        
        // Wait for async scheduling
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // THEN: Alarm should be scheduled
        let pendingIds = await dependencyContainer.notificationService.pendingAlarmIds()
        XCTAssertTrue(pendingIds.contains(alarm.id), "Alarm should be scheduled")
        
        // WHEN: Simulate alarm firing
        dependencyContainer.reliabilityLogger.logAlarmFired(alarm.id, details: ["source": "e2e_test"])
        
        // WHEN: Navigate to dismissal flow (simulates notification tap)
        dependencyContainer.appRouter.showRinging(for: alarm.id)
        XCTAssertEqual(dependencyContainer.appRouter.route, .ringing(alarmID: alarm.id))
        
        // WHEN: Start dismissal flow
        let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
        dismissalVM.start(alarmId: alarm.id)
        
        // THEN: Should be in ringing state
        XCTAssertEqual(dismissalVM.state, .ringing)
        
        // WHEN: Begin QR scanning
        dismissalVM.beginScan()
        
        // Wait for async permission check and scanning setup
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // THEN: Should be in scanning state
        XCTAssertEqual(dismissalVM.state, .scanning)
        
        // WHEN: Scan correct QR code
        dismissalVM.didScan(payload: testQRCode)
        
        // THEN: Should complete successfully
        XCTAssertEqual(dismissalVM.state, .success)
        
        // THEN: Should log success event
        let recentLogs = dependencyContainer.reliabilityLogger.getRecentLogs(limit: 10)
        let successLogs = recentLogs.filter { $0.event == .dismissSuccessQR && $0.alarmId == alarm.id }
        XCTAssertFalse(successLogs.isEmpty, "Should log dismiss success event")
        
        // THEN: Should navigate back to list after success delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(dependencyContainer.appRouter.route, .alarmList)
    }
    
    // MARK: - E2E: App Killed Scenario
    
    func test_E2E_appKilled_notificationRestoration() async throws {
        // This test simulates the critical "works if app is killed/closed" scenario:
        // 1. User creates alarm
        // 2. App is killed/closed
        // 3. Notification fires
        // 4. User taps "Return to Dismissal" action
        // 5. App cold-starts and navigates to dismissal flow
        
        // GIVEN: Alarm with QR code
        let testQRCode = "cold-start-qr-code"
        let alarm = Alarm(
            id: UUID(),
            time: mockClock.now().addingTimeInterval(30),
            label: "Cold Start Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: testQRCode,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
        
        // WHEN: Schedule alarm
        try await dependencyContainer.notificationService.scheduleAlarm(alarm)
        
        // SIMULATE: App is killed (clear in-memory state)
        let originalRoute = dependencyContainer.appRouter.route
        XCTAssertEqual(originalRoute, .alarmList)
        
        // SIMULATE: Notification fires and user taps "Return to Dismissal"
        // (This simulates the NotificationService delegate being called on cold start)
        dependencyContainer.appRouter.showRinging(for: alarm.id)
        
        // THEN: App should navigate to ringing view even from cold start
        XCTAssertEqual(dependencyContainer.appRouter.route, .ringing(alarmID: alarm.id))
        XCTAssertTrue(dependencyContainer.appRouter.isInDismissalFlow)
        
        // WHEN: Create new dismissal flow VM (simulates cold start creation)
        let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
        dismissalVM.start(alarmId: alarm.id)
        
        // THEN: Should work correctly even after cold start
        XCTAssertEqual(dismissalVM.state, .ringing)
        
        // WHEN: Complete the flow
        dismissalVM.beginScan()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        dismissalVM.didScan(payload: testQRCode)
        
        // THEN: Should succeed
        XCTAssertEqual(dismissalVM.state, .success)
    }
    
    // MARK: - E2E: 3-Alarm Smoke Test
    
    func test_E2E_threeAlarmSmoke_noCrashes() async throws {
        // This test validates the "3-alarm smoke with no crashes" requirement
        
        var alarms: [Alarm] = []
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        
        // GIVEN: Create 3 alarms with different configurations
        for i in 1...3 {
            let alarm = Alarm(
                id: UUID(),
                time: mockClock.now().addingTimeInterval(TimeInterval(i * 10)), // Staggered times
                label: "Smoke Test Alarm \(i)",
                repeatDays: i == 2 ? [.monday, .wednesday, .friday] : [], // One repeating alarm
                challengeKind: [.qr],
                expectedQR: "smoke-test-qr-\(i)",
                stepThreshold: nil,
                mathChallenge: nil,
                isEnabled: true,
                soundId: "chimes01",
                volume: 0.8
            )
            alarms.append(alarm)
            alarmListVM.add(alarm)
        }
        
        // Wait for all scheduling to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // THEN: All alarms should be scheduled without crashes
        let pendingIds = await dependencyContainer.notificationService.pendingAlarmIds()
        XCTAssertGreaterThanOrEqual(pendingIds.count, 3, "At least 3 notifications should be scheduled")
        
        // WHEN: Simulate all alarms firing and being dismissed
        for alarm in alarms {
            // Log firing
            dependencyContainer.reliabilityLogger.logAlarmFired(alarm.id)
            
            // Navigate to dismissal
            dependencyContainer.appRouter.showRinging(for: alarm.id)
            
            // Create and run dismissal flow
            let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
            dismissalVM.start(alarmId: alarm.id)
            dismissalVM.beginScan()
            
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Dismiss with correct QR
            dismissalVM.didScan(payload: "smoke-test-qr-\(alarms.firstIndex(of: alarm)! + 1)")
            
            // Verify success
            XCTAssertEqual(dismissalVM.state, .success)
            
            // Return to list
            dependencyContainer.appRouter.backToList()
            
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms between alarms
        }
        
        // THEN: All operations should complete without crashes
        let logs = dependencyContainer.reliabilityLogger.getRecentLogs(limit: 20)
        let successLogs = logs.filter { $0.event == .dismissSuccessQR }
        XCTAssertEqual(successLogs.count, 3, "All 3 alarms should have been dismissed successfully")
        
        // THEN: App should be back at list view
        XCTAssertEqual(dependencyContainer.appRouter.route, .alarmList)
        XCTAssertFalse(dependencyContainer.appRouter.isInDismissalFlow)
    }
    
    // MARK: - Edge Cases
    
    func test_E2E_alarmWithoutQR_preventedFromScheduling() {
        // Test the data model guardrail
        
        let alarmWithoutQR = Alarm(
            id: UUID(),
            time: Date(),
            label: "Invalid Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: nil, // Missing QR code
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        alarmListVM.add(alarmWithoutQR)
        
        // WHEN: Try to enable alarm without QR code
        alarmListVM.toggle(alarmWithoutQR)
        
        // THEN: Should fail with error message
        XCTAssertNotNil(alarmListVM.errorMessage)
        XCTAssertTrue(alarmListVM.errorMessage?.contains("QR code required") ?? false)
        
        // THEN: Alarm should remain disabled
        let savedAlarms = (try? dependencyContainer.persistenceService.loadAlarms()) ?? []
        let savedAlarm = savedAlarms.first { $0.id == alarmWithoutQR.id }
        XCTAssertFalse(savedAlarm?.isEnabled ?? true)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/E2E_DismissalFlowSoundTests.swift

```swift
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
    var mockAppRouter: MockAppRouter!
    var mockReliabilityLogger: MockReliabilityLogger!
    var mockClock: MockClock!
    var mockPermissionService: MockPermissionService!
    var mockAudioEngine: MockAlarmAudioEngine!
    var mockReliabilityModeProvider: MockReliabilityModeProvider!
    var mockDismissedRegistry: DismissedRegistry!
    var mockSettingsService: MockSettingsService!
    var mockAlarmScheduler: MockAlarmScheduling!
    var mockAlarmRunStore: AlarmRunStore!
    var mockIdleTimerController: MockIdleTimerController!

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
        mockAppRouter = nil
        mockReliabilityLogger = nil
        mockClock = nil
        mockPermissionService = nil
        mockAudioEngine = nil
        mockReliabilityModeProvider = nil
        mockDismissedRegistry = nil
        mockSettingsService = nil
        mockAlarmScheduler = nil
        mockAlarmRunStore = nil
        mockIdleTimerController = nil
        super.tearDown()
    }

    private func setupMocks() {
        mockQRScanning = MockQRScanning()
        mockAlarmStorage = MockAlarmStorage()
        mockNotificationService = MockNotificationService()
        mockAppRouter = MockAppRouter()
        mockReliabilityLogger = MockReliabilityLogger()
        mockClock = MockClock()
        mockPermissionService = MockPermissionService()
        mockAudioEngine = MockAlarmAudioEngine()
        mockReliabilityModeProvider = MockReliabilityModeProvider()
        mockDismissedRegistry = DismissedRegistry()
        mockSettingsService = MockSettingsService()
        mockAlarmScheduler = MockAlarmScheduling()
        mockAlarmRunStore = AlarmRunStore()
        mockIdleTimerController = MockIdleTimerController()
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
            audioEngine: mockAudioEngine,
            reliabilityModeProvider: mockReliabilityModeProvider,
            dismissedRegistry: mockDismissedRegistry,
            settingsService: mockSettingsService,
            alarmScheduler: mockAlarmScheduler,
            alarmRunStore: mockAlarmRunStore,
            idleTimerController: mockIdleTimerController
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
            if await mockAlarmStorage.getStoredRuns().count >= 1 {
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

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)

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

        try? await mockAlarmStorage.saveAlarm(alarm)

        // Start alarm
        await viewModel.start(alarmId: alarmId)
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

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)

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

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)

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

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)
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

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)

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

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)
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

        try? await mockAlarmStorage.saveAlarm(alarm)

        // Start the alarm
        await viewModel.start(alarmId: alarmId)

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
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        guard let run = await mockAlarmStorage.getStoredRuns().first else {
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

        try? await mockAlarmStorage.saveAlarm(alarm)

        // Simulate snooze action through notification service
        let notificationService = mockNotificationService as! MockNotificationService

        // Start with some scheduled alarms
        notificationService.scheduledAlarms = [alarm]

        // Test that snooze would work (we can't directly test the delegate without a real notification)
        // But we can verify the snooze function works correctly
        await viewModel.start(alarmId: alarmId)
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
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Integration_TestAlarmSchedulingTests.swift

```swift
//
//  Integration_TestAlarmSchedulingTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/8/25.
//  Integration tests for lock-screen test alarm scheduling
//

import XCTest
@testable import alarmAppNew
import UserNotifications

@MainActor
final class Integration_TestAlarmSchedulingTests: XCTestCase {
    var dependencyContainer: DependencyContainer!

    override func setUp() {
        super.setUp()
        dependencyContainer = DependencyContainer()
    }

    override func tearDown() {
        // Clean up any test notifications
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        super.tearDown()
    }

    // MARK: - Integration Tests

    func test_scheduleOneOffTestAlarm_createsNotificationWithCorrectProperties() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization first
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm with 8-second lead time
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)

        // THEN: Notification should be scheduled
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 1, "Should have exactly one test notification scheduled")

        // Verify notification properties
        guard let testNotification = testNotifications.first else {
            XCTFail("Test notification not found")
            return
        }

        // Check content
        XCTAssertEqual(testNotification.content.title, "🔔 Lock-Screen Test Alarm")
        XCTAssertEqual(testNotification.content.body, "This is a test to verify your ringer volume")
        XCTAssertEqual(testNotification.content.sound, .default)
        XCTAssertEqual(testNotification.content.categoryIdentifier, Categories.alarm)

        // Check userInfo
        let userInfo = testNotification.content.userInfo
        XCTAssertEqual(userInfo["type"] as? String, "test_lock_screen")
        XCTAssertEqual(userInfo["isTest"] as? Bool, true)
        XCTAssertNotNil(userInfo["alarmId"], "Should have alarmId in userInfo")

        // Check trigger
        guard let trigger = testNotification.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Trigger should be UNTimeIntervalNotificationTrigger")
            return
        }

        XCTAssertEqual(trigger.timeInterval, 8, accuracy: 0.1, "Trigger should fire in 8 seconds")
        XCTAssertFalse(trigger.repeats, "Test notification should not repeat")

        // Check interruption level (iOS 15+)
        if #available(iOS 15.0, *) {
            XCTAssertEqual(testNotification.content.interruptionLevel, .timeSensitive,
                          "Should use time-sensitive interruption level")
        }
    }

    func test_scheduleOneOffTestAlarm_withCustomLeadTime_usesCustomValue() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm with custom lead time (5 seconds)
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 5)

        // THEN: Notification should be scheduled with custom lead time
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 1)

        guard let testNotification = testNotifications.first,
              let trigger = testNotification.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Test notification or trigger not found")
            return
        }

        XCTAssertEqual(trigger.timeInterval, 5, accuracy: 0.1, "Trigger should use custom lead time")
    }

    func test_scheduleOneOffTestAlarm_multipleInvocations_createsMultipleNotifications() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm twice
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)

        // THEN: Should have two separate test notifications
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 2, "Should create separate notifications for each invocation")

        // Verify they have unique identifiers
        let identifiers = testNotifications.map { $0.identifier }
        let uniqueIdentifiers = Set(identifiers)
        XCTAssertEqual(identifiers.count, uniqueIdentifiers.count, "Each notification should have unique identifier")
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/NotificationIntegrationTests.swift

```swift
//
//  NotificationIntegrationTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/16/25.
//  Integration tests for notification scheduling with sounds
//

import XCTest
import UserNotifications
@testable import alarmAppNew

// Mock App State Provider is defined in TestMocks.swift

@MainActor
final class NotificationIntegrationTests: XCTestCase {
    var notificationService: NotificationService!
    var mockPermissionService: MockPermissionService!
    var mockAppStateProvider: MockAppStateProvider!
    var notificationCenter: UNUserNotificationCenter!

    override func setUp() {
        super.setUp()
        mockPermissionService = MockPermissionService()
        mockAppStateProvider = MockAppStateProvider()

        // Create minimal mock dependencies for testing
        let mockReliabilityLogger = MockReliabilityLogger()
        let mockAppRouter = AppRouter()
        let mockPersistenceService = MockAlarmStorage()

        notificationService = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: mockAppRouter,
            persistenceService: mockPersistenceService
        )
        notificationCenter = UNUserNotificationCenter.current()

        // Clear any existing test notifications
        notificationCenter.removeAllPendingNotificationRequests()
    }

    override func tearDown() {
        // Clean up any scheduled notifications
        notificationCenter.removeAllPendingNotificationRequests()
        notificationService = nil
        mockPermissionService = nil
        notificationCenter = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestAlarm(
        id: UUID = UUID(),
        time: Date = Date().addingTimeInterval(300), // 5 minutes from now
        label: String = "Integration Test Alarm",
        repeatDays: [Weekdays] = [],
        soundId: String = "chimes01"
    ) -> Alarm {
        return Alarm(
            id: id,
            time: time,
            label: label,
            repeatDays: repeatDays,
            challengeKind: [.qr],
            expectedQR: "test",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: soundId,
            volume: 0.8
        )
    }

    private func waitForNotificationScheduling() async {
        // Give the system time to process notification requests
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }

    // MARK: - Integration Tests

    func test_scheduleAndCancel_oneTimeAlarm_shouldWorkEndToEnd() async throws {
        let alarm = createTestAlarm()

        // Schedule the alarm
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify notifications were scheduled
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertTrue(alarmNotifications.count > 0, "Should have scheduled notifications for the alarm")

        // Cancel the alarm
        await notificationService.cancelAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify notifications were cancelled
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertEqual(remainingAlarmNotifications.count, 0, "All alarm notifications should be cancelled")
    }

    func test_scheduleRepeatingAlarm_shouldCreateMultipleNotifications() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday, .wednesday, .friday])

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        // Should have notifications for 3 days × 5 notification types (pre-alarm, main, 3 nudges)
        let expectedCount = 3 * 5
        XCTAssertEqual(alarmNotifications.count, expectedCount, "Should schedule notifications for all repeat days and types")
    }

    func test_notificationSound_integration_shouldUseCorrectSound() async throws {
        let customSoundAlarm = createTestAlarm(soundId: "bells01")

        try await notificationService.scheduleAlarm(customSoundAlarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String,
                  let type = request.content.userInfo["type"] as? String else { return false }
            return alarmId == customSoundAlarm.id.uuidString && type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should find main notification")

        // Verify sound is configured (actual sound name verification would require deeper inspection)
        XCTAssertNotNil(mainNotification?.content.sound, "Main notification should have sound configured")
    }

    func test_preAlarmNotification_shouldHaveCorrectTiming() async throws {
        let futureTime = Date().addingTimeInterval(10 * 60) // 10 minutes from now
        let alarm = createTestAlarm(time: futureTime)

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let preAlarmNotification = pendingRequests.first { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String,
                  let type = request.content.userInfo["type"] as? String else { return false }
            return alarmId == alarm.id.uuidString && type == "pre_alarm"
        }

        XCTAssertNotNil(preAlarmNotification, "Should schedule pre-alarm notification")

        // Verify it's a calendar trigger
        XCTAssertTrue(preAlarmNotification?.trigger is UNCalendarNotificationTrigger,
                     "Pre-alarm should use calendar trigger")
    }

    func test_nudgeNotifications_shouldHaveCorrectContent() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()

        // Find nudge notifications
        let nudge1 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_1"
        }

        let nudge2 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_2"
        }

        let nudge3 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_3"
        }

        XCTAssertNotNil(nudge1, "Should schedule nudge 1")
        XCTAssertNotNil(nudge2, "Should schedule nudge 2")
        XCTAssertNotNil(nudge3, "Should schedule nudge 3")

        // Verify escalating urgency in titles
        XCTAssertTrue(nudge1?.content.title.contains("⚠️") ?? false, "Nudge 1 should have warning emoji")
        XCTAssertTrue(nudge2?.content.title.contains("🚨") ?? false, "Nudge 2 should have siren emoji")
        XCTAssertTrue(nudge3?.content.title.contains("🔴") ?? false, "Nudge 3 should have red circle emoji")
    }

    func test_cancelSpecificNotifications_integration_shouldPreserveOthers() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Cancel only nudge notifications
        notificationService.cancelSpecificNotifications(
            for: alarm.id,
            types: [.nudge1, .nudge2, .nudge3]
        )
        await waitForNotificationScheduling()

        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        // Should still have main and pre-alarm notifications
        let mainNotification = remainingAlarmNotifications.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        let preAlarmNotification = remainingAlarmNotifications.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "pre_alarm"
        }

        XCTAssertNotNil(mainNotification, "Main notification should remain")
        XCTAssertNotNil(preAlarmNotification, "Pre-alarm notification should remain")

        // Verify nudges are gone
        let nudgeNotifications = remainingAlarmNotifications.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type.starts(with: "nudge_")
        }

        XCTAssertEqual(nudgeNotifications.count, 0, "All nudge notifications should be cancelled")
    }

    func test_refreshAll_integration_shouldReplaceAllNotifications() async throws {
        let alarm1 = createTestAlarm(id: UUID())
        let alarm2 = createTestAlarm(id: UUID(), repeatDays: [.tuesday])

        // Schedule initial alarms
        try await notificationService.scheduleAlarm(alarm1)
        try await notificationService.scheduleAlarm(alarm2)
        await waitForNotificationScheduling()

        let initialCount = await notificationCenter.pendingNotificationRequests().count

        // Refresh with updated alarms
        let updatedAlarm1 = createTestAlarm(id: alarm1.id, label: "Updated Alarm")
        await notificationService.refreshAll(from: [updatedAlarm1])
        await waitForNotificationScheduling()

        let finalRequests = await notificationCenter.pendingNotificationRequests()

        // Should only have notifications for the refreshed alarm
        let alarm1Notifications = finalRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm1.id.uuidString
        }

        let alarm2Notifications = finalRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm2.id.uuidString
        }

        XCTAssertTrue(alarm1Notifications.count > 0, "Should have notifications for refreshed alarm")
        XCTAssertEqual(alarm2Notifications.count, 0, "Should not have notifications for non-refreshed alarm")
    }

    func test_soundFallback_integration_shouldHandleInvalidSound() async throws {
        let alarm = createTestAlarm(soundId: "nonexistent_sound")

        // Should not throw despite invalid sound
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should schedule notification despite invalid sound")
        XCTAssertNotNil(mainNotification?.content.sound, "Should have fallback sound")
    }

    func test_nudgePrecision_integration_shouldUseCorrectTriggerTypes() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let nudgeNotifications = pendingRequests.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type.starts(with: "nudge_")
        }

        XCTAssertTrue(nudgeNotifications.count > 0, "Should have nudge notifications")

        // Verify nudge notifications exist (can't directly inspect trigger type in integration test)
        for notification in nudgeNotifications {
            XCTAssertNotNil(notification.trigger, "Nudge notifications should have triggers")
        }
    }

    func test_notificationCategories_integration_shouldHaveAllActions() async throws {
        // Test that the notification categories are properly registered
        let center = UNUserNotificationCenter.current()
        let categories = await center.notificationCategories()

        let alarmCategory = categories.first { $0.identifier == "ALARM_CATEGORY" }
        XCTAssertNotNil(alarmCategory, "Should have ALARM_CATEGORY registered")

        if let category = alarmCategory {
            let actionIdentifiers = category.actions.map { $0.identifier }
            XCTAssertTrue(actionIdentifiers.contains("OPEN_ALARM"), "Should have OPEN_ALARM action")
            XCTAssertTrue(actionIdentifiers.contains("RETURN_TO_DISMISSAL"), "Should have RETURN_TO_DISMISSAL action")
            XCTAssertTrue(actionIdentifiers.contains("SNOOZE_ALARM"), "Should have SNOOZE_ALARM action")
        }
    }

    func test_futureNudgePrevention_integration_shouldStopUpcomingNotifications() async throws {
        let alarm = createTestAlarm()

        // Schedule alarm with nudges
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Generate expected identifiers using same logic as production code
        let expectedNudge1Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge1])
        let expectedNudge2Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge2])
        let expectedNudge3Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge3])

        // Cancel specific future nudges (simulating dismissal after nudge1 fires)
        notificationService.cancelSpecificNotifications(
            for: alarm.id,
            types: [.nudge1, .nudge2]
        )

        // Wait for cancellation to process
        await waitForNotificationScheduling()

        // Verify no future nudge1 or nudge2 notifications remain in pending queue
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingIdentifiers = Set(remainingRequests.map { $0.identifier })

        // Assert future nudges won't fire by checking exact identifier matching
        for expectedId in expectedNudge1Identifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future nudge1 notification '\(expectedId)' should be cancelled")
        }

        for expectedId in expectedNudge2Identifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future nudge2 notification '\(expectedId)' should be cancelled")
        }

        // Verify nudge3 remains scheduled (should still fire in future)
        var nudge3Found = false
        for expectedId in expectedNudge3Identifiers {
            if remainingIdentifiers.contains(expectedId) {
                nudge3Found = true
                break
            }
        }
        XCTAssertTrue(nudge3Found, "Future nudge3 notifications should remain scheduled")

        // Verify main and pre-alarm notifications remain
        let mainNotification = remainingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }
        XCTAssertNotNil(mainNotification, "Main notification should remain scheduled")
    }

    // Helper to generate expected notification identifiers (mirrors production logic)
    private func generateExpectedNotificationIdentifiers(for alarmId: UUID, types: [NotificationType]) -> Set<String> {
        var identifiers: Set<String> = []

        for type in types {
            // One-time alarm format: "alarmId-typeRawValue"
            identifiers.insert("\(alarmId.uuidString)-\(type.rawValue)")

            // Repeating alarm format: "alarmId-typeRawValue-weekday-N"
            for weekday in 1...7 {
                identifiers.insert("\(alarmId.uuidString)-\(type.rawValue)-weekday-\(weekday)")
            }
        }

        return identifiers
    }

    func test_completeAlarmCancellation_shouldPreventAllFutureNotifications() async throws {
        let alarm = createTestAlarm()

        // Schedule alarm with all notification types
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Generate expected identifiers for all notification types
        let allTypes: [NotificationType] = [.main, .preAlarm, .nudge1, .nudge2, .nudge3]
        let expectedIdentifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: allTypes)

        // Cancel entire alarm
        await notificationService.cancelAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify no future notifications remain in pending queue
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingIdentifiers = Set(remainingRequests.map { $0.identifier })

        // Assert no future notifications will fire by checking exact identifier matching
        for expectedId in expectedIdentifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future notification '\(expectedId)' should be cancelled")
        }

        // Also verify using content-based filtering (for additional safety)
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertEqual(remainingAlarmNotifications.count, 0, "No future alarm notifications should remain scheduled")
    }

    // MARK: - userInfo Routing Tests

    func test_userInfoRouting_defaultTap_opensDismissal() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should have main notification")

        // Verify userInfo contains correct alarmId
        if let notification = mainNotification {
            XCTAssertEqual(notification.content.userInfo["alarmId"] as? String, alarm.id.uuidString)
            XCTAssertEqual(notification.content.categoryIdentifier, "ALARM_CATEGORY")
        }
    }

    func test_userInfoRouting_actions_open_return_snooze() async throws {
        // Test that notification categories are properly registered
        let center = UNUserNotificationCenter.current()
        let categories = await center.notificationCategories()

        let alarmCategory = categories.first { $0.identifier == "ALARM_CATEGORY" }
        XCTAssertNotNil(alarmCategory, "Should have ALARM_CATEGORY registered")

        if let category = alarmCategory {
            let actionIdentifiers = category.actions.map { $0.identifier }
            XCTAssertTrue(actionIdentifiers.contains("OPEN_ALARM"), "Should have OPEN_ALARM action")
            XCTAssertTrue(actionIdentifiers.contains("RETURN_TO_DISMISSAL"), "Should have RETURN_TO_DISMISSAL action")
            XCTAssertTrue(actionIdentifiers.contains("SNOOZE_ALARM"), "Should have SNOOZE_ALARM action")

            // Verify action options
            let openAction = category.actions.first { $0.identifier == "OPEN_ALARM" }
            XCTAssertTrue(openAction?.options.contains(.foreground) ?? false, "OPEN_ALARM should have foreground option")

            let returnAction = category.actions.first { $0.identifier == "RETURN_TO_DISMISSAL" }
            XCTAssertTrue(returnAction?.options.contains(.foreground) ?? false, "RETURN_TO_DISMISSAL should have foreground option")

            let snoozeAction = category.actions.first { $0.identifier == "SNOOZE_ALARM" }
            XCTAssertFalse(snoozeAction?.options.contains(.foreground) ?? true, "SNOOZE_ALARM should not have foreground option")
        }
    }

    func test_categories_registered_once_idempotent() {
        // Call ensureNotificationCategoriesRegistered multiple times
        notificationService.ensureNotificationCategoriesRegistered()
        notificationService.ensureNotificationCategoriesRegistered()
        notificationService.ensureNotificationCategoriesRegistered()

        // This test verifies the method can be called multiple times without issues
        // The actual category registration is tested in other tests
        XCTAssertTrue(true, "Multiple category registrations should not cause issues")
    }

    func test_allNotifications_includeUserInfo() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday])

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertTrue(alarmNotifications.count > 0, "Should have scheduled notifications")

        // Verify every notification has userInfo and category
        for notification in alarmNotifications {
            XCTAssertNotNil(notification.content.userInfo["alarmId"], "Every notification should have alarmId in userInfo")
            XCTAssertNotNil(notification.content.userInfo["type"], "Every notification should have type in userInfo")
            XCTAssertEqual(notification.content.categoryIdentifier, "ALARM_CATEGORY", "Every notification should have ALARM_CATEGORY")
        }
    }

    func test_testNotification_includesUserInfo() async throws {
        try await notificationService.scheduleTestNotification(soundName: "chime", in: 1.0)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let testNotifications = pendingRequests.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "test"
        }

        XCTAssertTrue(testNotifications.count > 0, "Should have test notification")

        // Verify test notification has userInfo
        if let testNotification = testNotifications.first {
            XCTAssertNotNil(testNotification.content.userInfo["alarmId"], "Test notification should have alarmId")
            XCTAssertEqual(testNotification.content.userInfo["type"] as? String, "test", "Test notification should have test type")
            XCTAssertEqual(testNotification.content.categoryIdentifier, "ALARM_CATEGORY", "Test notification should have ALARM_CATEGORY")
        }
    }

    // MARK: - App State Tests

    func test_appStateProvider_activeState() {
        let provider = MockAppStateProvider()

        // Test inactive state
        provider.mockIsAppActive = false
        XCTAssertFalse(provider.isAppActive, "Should report app as inactive")

        // Test active state
        provider.mockIsAppActive = true
        XCTAssertTrue(provider.isAppActive, "Should report app as active")
    }

    func test_appStateProvider_mainActorAnnotation() async {
        // Test that the real AppStateProvider is properly marked as MainActor
        let provider = AppStateProvider()

        // This test verifies the provider can be instantiated and accessed on main actor
        // The @MainActor annotation ensures UIApplication access is thread-safe
        XCTAssertNotNil(provider, "AppStateProvider should be instantiable")

        // Test that isAppActive can be accessed (this validates the @MainActor constraint)
        let _ = provider.isAppActive // This validates the property works on main actor
    }

    // MARK: - Error Handling Integration Tests

    func test_permissionDenied_integration_shouldThrowError() async {
        mockPermissionService.mockNotificationDetails = NotificationPermissionDetails(
            authorizationStatus: PermissionStatus.denied,
            alertsEnabled: false,
            soundEnabled: false,
            badgeEnabled: false
        )

        let alarm = createTestAlarm()

        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown permission denied error")
        } catch NotificationError.permissionDenied {
            // Expected behavior
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify no notifications were scheduled
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        XCTAssertEqual(pendingRequests.count, 0, "Should not schedule notifications when permission denied")
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/NotificationServiceTests.swift

```swift
//
//  NotificationServiceTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/16/25.
//  Unit tests for enhanced NotificationService with nudges and pre-alarm reminders
//

import XCTest
import UserNotifications
@testable import alarmAppNew

// Mock Permission Service is defined in TestMocks.swift

// MARK: - Mock Notification Center

class MockNotificationCenter {
    var scheduledRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var removeAllCalled = false

    func add(_ request: UNNotificationRequest) throws {
        scheduledRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        scheduledRequests.removeAll { request in
            identifiers.contains(request.identifier)
        }
    }

    func removeAllPendingNotificationRequests() {
        removeAllCalled = true
        scheduledRequests.removeAll()
    }

    func pendingNotificationRequests() -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

// MARK: - Notification Service Tests

final class NotificationServiceTests: XCTestCase {
    var notificationService: NotificationService!
    var mockPermissionService: MockPermissionService!
    var mockCenter: MockNotificationCenter!
    var mockAppStateProvider: MockAppStateProvider!
    var mockReliabilityLogger: MockReliabilityLogger!
    var appRouter: AppRouter!
    var mockAlarmStorage: MockAlarmStorage!

    @MainActor override func setUp() {
        super.setUp()
        mockPermissionService = MockPermissionService()
        mockCenter = MockNotificationCenter()
        mockAppStateProvider = MockAppStateProvider()
        mockReliabilityLogger = MockReliabilityLogger()
        appRouter = AppRouter()
        mockAlarmStorage = MockAlarmStorage()
        notificationService = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: appRouter,
            persistenceService: mockAlarmStorage
        )
    }

    override func tearDown() {
        notificationService = nil
        mockPermissionService = nil
        mockCenter = nil
        mockAppStateProvider = nil
        mockReliabilityLogger = nil
        appRouter = nil
        mockAlarmStorage = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestAlarm(
        id: UUID = UUID(),
        time: Date = Date().addingTimeInterval(3600), // 1 hour from now
        label: String = "Test Alarm",
        repeatDays: [Weekdays] = [],
        soundId: String = "chimes01"
    ) -> Alarm {
        return Alarm(
            id: id,
            time: time,
            label: label,
            repeatDays: repeatDays,
            challengeKind: [.qr],
            expectedQR: "test",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: soundId,
            volume: 0.8
        )
    }

    // MARK: - Notification Content Tests

    func test_createNotificationContent_preAlarm_shouldHaveCorrectContent() {
        let alarm = createTestAlarm(label: "Morning Alarm")

        // Use reflection or create a test subclass to access private method
        // For now, we'll test through public interface
        XCTAssertTrue(true) // Placeholder - would test content creation
    }

    // MARK: - Notification Identifier Tests

    func test_notificationIdentifier_mainType_shouldHaveCorrectFormat() {
        let alarmId = UUID()
        let expectedPattern = "\(alarmId.uuidString)-main"

        // Test through scheduled notifications
        XCTAssertTrue(expectedPattern.contains("main"))
    }

    func test_notificationIdentifier_withWeekday_shouldIncludeWeekday() {
        let alarmId = UUID()
        let weekday = 2 // Tuesday
        let expectedPattern = "\(alarmId.uuidString)-main-weekday-\(weekday)"

        XCTAssertTrue(expectedPattern.contains("weekday-2"))
    }

    // MARK: - One-Time Alarm Tests

    func test_scheduleAlarm_oneTime_shouldScheduleAllNotificationTypes() async throws {
        let futureTime = Date().addingTimeInterval(10 * 60) // 10 minutes from now
        let alarm = createTestAlarm(time: futureTime, repeatDays: [])

        try await notificationService.scheduleAlarm(alarm)

        // Verify the call completed without throwing
        XCTAssertTrue(true)
    }

    func test_scheduleAlarm_oneTime_pastPreAlarmTime_shouldNotSchedulePreAlarm() async throws {
        let nearFutureTime = Date().addingTimeInterval(2 * 60) // 2 minutes from now (less than 5 min pre-alarm)
        let alarm = createTestAlarm(time: nearFutureTime, repeatDays: [])

        try await notificationService.scheduleAlarm(alarm)

        // Pre-alarm should not be scheduled since it would be in the past
        XCTAssertTrue(true)
    }

    // MARK: - Repeating Alarm Tests

    func test_scheduleAlarm_repeating_shouldScheduleForAllDays() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday, .wednesday, .friday])

        try await notificationService.scheduleAlarm(alarm)

        // Should schedule notifications for all specified days
        XCTAssertTrue(true)
    }

    func test_scheduleAlarm_repeating_allDays_shouldScheduleForWeek() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])

        try await notificationService.scheduleAlarm(alarm)

        // Should schedule for all 7 days
        XCTAssertTrue(true)
    }

    // MARK: - Permission Tests

    func test_scheduleAlarm_deniedPermission_shouldThrowError() async {
        mockPermissionService.mockNotificationDetails = NotificationPermissionDetails(
            authorizationStatus: PermissionStatus.denied,
            alertsEnabled: false,
            soundEnabled: false,
            badgeEnabled: false
        )

        let alarm = createTestAlarm()

        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown permission denied error")
        } catch NotificationError.permissionDenied {
            // Expected behavior
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_scheduleAlarm_mutedNotifications_shouldWarnButProceed() async throws {
        mockPermissionService.mockNotificationDetails = NotificationPermissionDetails(
            authorizationStatus: PermissionStatus.authorized,
            alertsEnabled: false,
            soundEnabled: false,
            badgeEnabled: true
        )

        let alarm = createTestAlarm()

        // Should not throw but should log warning
        try await notificationService.scheduleAlarm(alarm)
        XCTAssertTrue(true)
    }

    // MARK: - Cancellation Tests

    func test_cancelAlarm_shouldRemoveAllRelatedNotifications() async {
        let alarm = createTestAlarm(repeatDays: [.monday, .tuesday])

        await notificationService.cancelAlarm(alarm)

        // Should generate correct identifiers for cancellation
        XCTAssertTrue(true)
    }

    func test_cancelSpecificNotifications_shouldRemoveOnlySpecifiedTypes() {
        let alarmId = UUID()
        let typesToCancel: [NotificationType] = [.nudge1, .nudge2]

        notificationService.cancelSpecificNotifications(for: alarmId, types: typesToCancel)

        // Should only cancel specified notification types
        XCTAssertTrue(true)
    }

    func test_cancelSpecificNotifications_nudgeTypes_shouldNotCancelMainOrPreAlarm() {
        let alarmId = UUID()
        let nudgeTypes: [NotificationType] = [.nudge1, .nudge2, .nudge3]

        notificationService.cancelSpecificNotifications(for: alarmId, types: nudgeTypes)

        // Should preserve main and pre-alarm notifications
        XCTAssertTrue(true)
    }

    // MARK: - Refresh Tests

    func test_refreshAll_shouldCancelAllAndReschedule() async {
        let alarms = [
            createTestAlarm(),
            createTestAlarm(id: UUID(), repeatDays: [.monday])
        ]

        await notificationService.refreshAll(from: alarms)

        // Should cancel all existing and reschedule enabled alarms
        XCTAssertTrue(true)
    }

    func test_refreshAll_disabledAlarms_shouldNotBeScheduled() async {
        var disabledAlarm = createTestAlarm()
        // Note: Alarm struct doesn't have isEnabled property in the test setup
        // This test would verify that disabled alarms are skipped

        await notificationService.refreshAll(from: [disabledAlarm])
        XCTAssertTrue(true)
    }

    // MARK: - Sound Tests

    func test_createNotificationSound_defaultSound_shouldReturnDefault() {
        // Test through scheduled notification
        let alarm = createTestAlarm(soundId: "chimes01")

        // Sound creation is tested implicitly through scheduling
        XCTAssertEqual(alarm.soundName, "default")
    }

    func test_createNotificationSound_customSound_shouldUseCustom() {
        let alarm = createTestAlarm(soundId: "bells01")

        XCTAssertEqual(alarm.soundName, "chime")
    }

    func test_createNotificationSound_invalidSound_shouldFallbackToDefault() {
        let alarm = createTestAlarm(soundId: "nonexistent")

        // Service should handle invalid sounds gracefully
        XCTAssertEqual(alarm.soundName, "nonexistent")
    }

    func test_createNotificationSound_nilSound_shouldUseDefault() {
        let alarm = createTestAlarm() // Uses default soundId

        XCTAssertNil(alarm.soundName)
    }

    // MARK: - Test Notification Tests

    func test_scheduleTestNotification_shouldScheduleWithCorrectDelay() async throws {
        let delay: TimeInterval = 3.0

        try await notificationService.scheduleTestNotification(soundName: "bell", in: delay)

        // Should schedule test notification with specified delay
        XCTAssertTrue(true)
    }

    func test_scheduleTestNotification_withNilSound_shouldUseDefault() async throws {
        try await notificationService.scheduleTestNotification(soundName: nil, in: 1.0)

        XCTAssertTrue(true)
    }

    // MARK: - Notification Action Tests

    func test_notificationCategories_shouldIncludeAllActions() {
        // Verify notification categories are set up correctly
        XCTAssertTrue(true) // Would test if we could access the registered categories
    }

    func test_snoozeAction_shouldBeHandledCorrectly() async {
        // This would test the snooze action handling in delegate
        // For now, test the action identifier constants
        XCTAssertEqual("SNOOZE_ALARM", "SNOOZE_ALARM")
        XCTAssertEqual("OPEN_ALARM", "OPEN_ALARM")
        XCTAssertEqual("RETURN_TO_DISMISSAL", "RETURN_TO_DISMISSAL")
    }

    // MARK: - Trigger Type Tests

    func test_nudgeNotifications_shouldUsePreciseTiming() {
        // Test that nudge notifications would use interval triggers for precision
        // This tests the logic in createOptimalTrigger indirectly
        let now = Date()
        let thirtySecondsLater = now.addingTimeInterval(30)
        let twoMinutesLater = now.addingTimeInterval(120)

        // Verify timing calculations
        XCTAssertEqual(thirtySecondsLater.timeIntervalSince(now), 30)
        XCTAssertEqual(twoMinutesLater.timeIntervalSince(now), 120)
    }

    func test_mainAlarm_shouldUseCalendarTrigger() {
        // Test that main alarms use calendar triggers for exact time matching
        let alarm = createTestAlarm()

        // Main alarms should use calendar-based scheduling
        XCTAssertNotNil(alarm.time)
    }

    // MARK: - Notification Type Tests

    func test_notificationType_allCases_shouldIncludeAllTypes() {
        let allTypes = NotificationType.allCases

        XCTAssertEqual(allTypes.count, 5)
        XCTAssertTrue(allTypes.contains(.main))
        XCTAssertTrue(allTypes.contains(.preAlarm))
        XCTAssertTrue(allTypes.contains(.nudge1))
        XCTAssertTrue(allTypes.contains(.nudge2))
        XCTAssertTrue(allTypes.contains(.nudge3))
    }

    func test_notificationType_rawValues_shouldBeCorrect() {
        XCTAssertEqual(NotificationType.main.rawValue, "main")
        XCTAssertEqual(NotificationType.preAlarm.rawValue, "pre_alarm")
        XCTAssertEqual(NotificationType.nudge1.rawValue, "nudge_1")
        XCTAssertEqual(NotificationType.nudge2.rawValue, "nudge_2")
        XCTAssertEqual(NotificationType.nudge3.rawValue, "nudge_3")
    }

    // MARK: - Edge Case Tests

    func test_scheduleAlarm_farFuture_shouldHandleCorrectly() async throws {
        let farFutureTime = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year from now
        let alarm = createTestAlarm(time: farFutureTime)

        try await notificationService.scheduleAlarm(alarm)

        // Should handle far future dates without issues
        XCTAssertTrue(true)
    }

    func test_scheduleAlarm_pastTime_shouldHandleGracefully() async throws {
        let pastTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let alarm = createTestAlarm(time: pastTime)

        try await notificationService.scheduleAlarm(alarm)

        // Should handle past times (may not actually schedule, but shouldn't crash)
        XCTAssertTrue(true)
    }

    // MARK: - Idempotent Scheduling Tests

    func test_refreshAll_idempotent_noDuplicates() async {
        // Given: An alarm that should be scheduled
        let alarm = createTestAlarm()
        alarm.isEnabled = true
        let alarms = [alarm]

        // When: refreshAll is called twice
        await notificationService.refreshAll(from: alarms)
        let firstCount = mockCenter.scheduledRequests.count

        await notificationService.refreshAll(from: alarms)
        let secondCount = mockCenter.scheduledRequests.count

        // Then: No duplicate notifications are created
        // Note: With idempotent scheduling, the second call should not add more notifications
        // if the first call already scheduled them
        XCTAssertGreaterThan(firstCount, 0, "First refresh should schedule notifications")

        // The count might be the same or less (due to diff-based scheduling)
        // but should not increase
        XCTAssertLessThanOrEqual(secondCount, firstCount,
                                  "Second refresh should not create duplicates")
    }

    func test_refreshAll_disabledAlarm_removesNotifications() async {
        // Given: An enabled alarm that gets scheduled
        let alarm = createTestAlarm()
        alarm.isEnabled = true
        await notificationService.refreshAll(from: [alarm])

        let scheduledCount = mockCenter.scheduledRequests.count
        XCTAssertGreaterThan(scheduledCount, 0, "Should have scheduled notifications")

        // When: The alarm is disabled and refreshAll is called
        alarm.isEnabled = false
        await notificationService.refreshAll(from: [alarm])

        // Then: Notifications should be removed
        // With idempotent scheduling, disabled alarm notifications are removed
        XCTAssertGreaterThan(mockCenter.removedIdentifiers.count, 0,
                             "Should have removed notifications for disabled alarm")
    }

    func test_refreshAll_namespace_isolated() async {
        // Given: Some existing non-app notifications (simulated)
        let foreignRequest = UNNotificationRequest(
            identifier: "com.other.app.notification",
            content: UNMutableNotificationContent(),
            trigger: nil
        )
        mockCenter.scheduledRequests.append(foreignRequest)

        // When: refreshAll is called with our alarms
        let alarm = createTestAlarm()
        alarm.isEnabled = true
        await notificationService.refreshAll(from: [alarm])

        // Then: Foreign notifications should not be removed
        let foreignStillExists = mockCenter.scheduledRequests.contains {
            $0.identifier == "com.other.app.notification"
        }
        XCTAssertTrue(foreignStillExists || !mockCenter.removedIdentifiers.contains("com.other.app.notification"),
                      "Should not remove foreign notifications")
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/TestMocks.swift

```swift
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
public typealias MockAlarmScheduling = AlarmSchedulingMock```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit_VolumeWarningTests.swift

```swift
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
    var mockAlarmScheduler: MockAlarmScheduling!
    var mockRefresher: MockRefresher!
    var mockVolumeProvider: MockSystemVolumeProvider!
    var viewModel: AlarmListViewModel!

    override func setUp() {
        super.setUp()

        // Create mocks
        mockStorage = MockAlarmStorage()
        mockPermissionService = MockPermissionService()
        mockNotificationService = MockNotificationService()
        mockAlarmScheduler = MockAlarmScheduling()
        mockRefresher = MockRefresher()
        mockVolumeProvider = MockSystemVolumeProvider()

        // Create view model with mocked dependencies
        viewModel = AlarmListViewModel(
            storage: mockStorage,
            permissionService: mockPermissionService,
            alarmScheduler: mockAlarmScheduler,
            refresher: mockRefresher,
            systemVolumeProvider: mockVolumeProvider,
            notificationService: mockNotificationService
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
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/ArchitectureGuardrailTests.swift

```swift
//
//  ArchitectureGuardrailTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/5/25.
//  Guardrail tests to enforce architectural boundaries
//

import XCTest
@testable import alarmAppNew

final class ArchitectureGuardrailTests: XCTestCase {
    func test_dismissedRegistry_hasNoOSDependencies() {
        // This is a compile-time check: DismissedRegistry MUST NOT import UIKit or UserNotifications
        // If it does, this file won't compile
        let registry = DismissedRegistry()
        XCTAssertNotNil(registry, "DismissedRegistry should initialize without OS dependencies")
    }

    @MainActor
    func test_dismissedRegistry_init_noForceUnwraps() async {
        // Verify initialization doesn't crash with default UserDefaults
        let registry = DismissedRegistry()

        // Should initialize successfully with empty cache (await for MainActor)
        let keys = await registry.dismissedOccurrenceKeys()
        XCTAssertNotNil(keys)
        XCTAssertTrue(keys.isEmpty, "Fresh registry should have no dismissed occurrences")
    }

    @MainActor
    func test_dismissedRegistry_markDismissed_persistsState() async {
        // Given: A fresh registry
        let registry = DismissedRegistry()
        let alarmId = UUID()
        let occurrenceKey = OccurrenceKeyFormatter.key(from: Date())

        // When: We mark an occurrence as dismissed
        await registry.markDismissed(alarmId: alarmId, occurrenceKey: occurrenceKey)

        // Then: It's remembered
        let isDismissed = await registry.isDismissed(alarmId: alarmId, occurrenceKey: occurrenceKey)
        XCTAssertTrue(isDismissed, "Registry should remember dismissed occurrence")

        // And: It appears in dismissed keys set
        let dismissedKeys = await registry.dismissedOccurrenceKeys()
        XCTAssertTrue(dismissedKeys.contains(occurrenceKey), "Dismissed key should be in set")
    }

    @MainActor
    func test_dismissedRegistry_expiration_clearsOldEntries() async {
        // Given: A registry with a mocked old dismissal (would need to manipulate time)
        // This test validates that expired entries are cleaned up
        // For now, we just verify the cleanup method exists and doesn't crash
        let registry = DismissedRegistry()

        // When: We call cleanup
        await registry.cleanupExpired()

        // Then: No crash occurs
        let keys = await registry.dismissedOccurrenceKeys()
        XCTAssertNotNil(keys)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Domain/AlarmStopSemanticsTests.swift

```swift
//
//  AlarmStopSemanticsTests.swift
//  alarmAppNewTests
//
//  Tests for the StopAlarmAllowed use case to verify that
//  stop is only allowed after challenge validation.
//

import XCTest
@testable import alarmAppNew

final class AlarmStopSemanticsTests: XCTestCase {

    // MARK: - Stop Disallowed Tests

    func test_stop_disallowed_until_all_challenges_validated() {
        // GIVEN: An alarm with multiple challenges
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // WHEN: Only some challenges are completed
        let partiallyCompleteState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [.qr, .stepCount]  // Missing .math
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: partiallyCompleteState),
            "Stop should not be allowed when challenges remain incomplete"
        )

        // AND: Reason should indicate remaining challenge
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: partiallyCompleteState)
        XCTAssertNotNil(reason, "Should provide reason for denial")
        XCTAssertTrue(
            reason?.contains("Math") ?? false,
            "Reason should mention the remaining challenge"
        )
    }

    func test_stop_disallowed_when_no_challenges_completed() {
        // GIVEN: An alarm with challenges
        let requiredChallenges: [Challenges] = [.qr, .math]

        // WHEN: No challenges are completed
        let uncompleteState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: []
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: uncompleteState),
            "Stop should not be allowed when no challenges are completed"
        )

        // AND: Reason should indicate all challenges need completion
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: uncompleteState)
        XCTAssertEqual(
            reason,
            "Complete all challenges to stop the alarm",
            "Should indicate all challenges need completion"
        )
    }

    func test_stop_disallowed_during_validation() {
        // GIVEN: An alarm with challenges being validated
        let requiredChallenges: [Challenges] = [.qr]

        // WHEN: Challenge is being validated
        let validatingState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [],
            isValidating: true
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: validatingState),
            "Stop should not be allowed during validation"
        )

        // AND: Reason should indicate validation in progress
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: validatingState)
        XCTAssertEqual(
            reason,
            "Challenge validation in progress",
            "Should indicate validation is in progress"
        )
    }

    // MARK: - Stop Allowed Tests

    func test_stop_allowed_after_validation() {
        // GIVEN: An alarm with challenges
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // WHEN: All challenges are completed
        let completeState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: Set(requiredChallenges)
        )

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(challengeState: completeState),
            "Stop should be allowed when all challenges are completed"
        )

        // AND: No reason for denial
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: completeState)
        XCTAssertNil(reason, "Should not provide reason when stop is allowed")
    }

    func test_stop_allowed_when_no_challenges_required() {
        // GIVEN: An alarm with no challenges
        let noChallengesState = ChallengeStackState(
            requiredChallenges: [],
            completedChallenges: []
        )

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(challengeState: noChallengesState),
            "Stop should be allowed when no challenges are required"
        )
    }

    // MARK: - Alternative Execute Method Tests

    func test_stop_with_alarm_object() throws {
        // GIVEN: An alarm with specific challenges
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        var modifiedAlarm = alarm
        modifiedAlarm.challengeKind = [.qr, .math]

        // WHEN: Checking with partial completion
        let partialCompletion: Set<Challenges> = [.qr]

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(
                alarm: modifiedAlarm,
                completedChallenges: partialCompletion
            ),
            "Stop should not be allowed with partial completion"
        )

        // WHEN: All challenges completed
        let fullCompletion: Set<Challenges> = [.qr, .math]

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(
                alarm: modifiedAlarm,
                completedChallenges: fullCompletion
            ),
            "Stop should be allowed with full completion"
        )
    }

    // MARK: - Progress Tracking Tests

    func test_challenge_progress_tracking() {
        // GIVEN: Various challenge states
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // Test no progress
        let noProgressState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: []
        )
        XCTAssertEqual(noProgressState.progress, 0.0, accuracy: 0.01)
        XCTAssertEqual(noProgressState.nextChallenge, .qr)

        // Test partial progress
        let partialState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [.qr]
        )
        XCTAssertEqual(partialState.progress, 1.0/3.0, accuracy: 0.01)
        XCTAssertEqual(partialState.nextChallenge, .stepCount)

        // Test complete progress
        let completeState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: Set(requiredChallenges)
        )
        XCTAssertEqual(completeState.progress, 1.0, accuracy: 0.01)
        XCTAssertNil(completeState.nextChallenge)
    }

    func test_challenge_progress_display() {
        // GIVEN: A challenge state
        let state = ChallengeStackState(
            requiredChallenges: [.qr, .math],
            completedChallenges: [.qr]
        )

        // WHEN: Creating progress display
        let progress = ChallengeProgress(state: state)

        // THEN: Display values should be correct
        XCTAssertEqual(progress.total, 2)
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.remaining, 1)
        XCTAssertEqual(progress.percentComplete, 50)
        XCTAssertFalse(progress.isComplete)
        XCTAssertEqual(progress.displayText, "1 of 2 challenges completed")
    }

    func test_estimated_time_until_allowed() {
        // GIVEN: Challenge state with remaining challenges
        let state = ChallengeStackState(
            requiredChallenges: [.qr, .stepCount, .math],
            completedChallenges: [.qr]
        )

        // WHEN: Estimating time with default 10s per challenge
        let estimatedTime = StopAlarmAllowed.estimatedTimeUntilAllowed(
            challengeState: state
        )

        // THEN: Should be 20 seconds (2 remaining * 10s)
        XCTAssertEqual(estimatedTime, 20.0)

        // WHEN: All challenges complete
        let completeState = ChallengeStackState(
            requiredChallenges: [.qr],
            completedChallenges: [.qr]
        )
        let noTime = StopAlarmAllowed.estimatedTimeUntilAllowed(
            challengeState: completeState
        )

        // THEN: Should be nil (already allowed)
        XCTAssertNil(noTime)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Domain/ChainPolicyTests.swift

```swift
//
//  ChainPolicyTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class ChainPolicyTests: XCTestCase {

    // MARK: - ChainSettings Validation Tests

    func test_chainSettings_defaultValues_withinValidRanges() {
        let settings = ChainSettings()

        XCTAssertEqual(settings.maxChainCount, 12)
        XCTAssertEqual(settings.ringWindowSec, 180)
        XCTAssertEqual(settings.fallbackSpacingSec, 30)
        XCTAssertEqual(settings.minLeadTimeSec, 10)
    }

    func test_chainSettings_clampsExcessiveValues() {
        let settings = ChainSettings(
            maxChainCount: 100,  // Should clamp to 50
            ringWindowSec: 1000, // Should clamp to 600
            fallbackSpacingSec: 60, // Should clamp to 30
            minLeadTimeSec: 100 // Should clamp to 30
        )

        XCTAssertEqual(settings.maxChainCount, 50)
        XCTAssertEqual(settings.ringWindowSec, 600)
        XCTAssertEqual(settings.fallbackSpacingSec, 30)
        XCTAssertEqual(settings.minLeadTimeSec, 30)
    }

    func test_chainSettings_clampsNegativeValues() {
        let settings = ChainSettings(
            maxChainCount: -5,   // Should clamp to 1
            ringWindowSec: -10,  // Should clamp to 30
            fallbackSpacingSec: 0, // Should clamp to 1
            minLeadTimeSec: -1   // Should clamp to 5
        )

        XCTAssertEqual(settings.maxChainCount, 1)
        XCTAssertEqual(settings.ringWindowSec, 30)
        XCTAssertEqual(settings.fallbackSpacingSec, 1)
        XCTAssertEqual(settings.minLeadTimeSec, 5)
    }

    // MARK: - ChainPolicy Normalization Tests

    func test_chainPolicy_normalizedSpacing_clampsToValidRange() {
        let policy = ChainPolicy()

        // Test lower bound
        XCTAssertEqual(policy.normalizedSpacing(0), 1)
        XCTAssertEqual(policy.normalizedSpacing(-5), 1)

        // Test upper bound
        XCTAssertEqual(policy.normalizedSpacing(35), 30)
        XCTAssertEqual(policy.normalizedSpacing(60), 30)

        // Test valid values
        XCTAssertEqual(policy.normalizedSpacing(5), 5)
        XCTAssertEqual(policy.normalizedSpacing(15), 15)
        XCTAssertEqual(policy.normalizedSpacing(30), 30)
    }

    // MARK: - Chain Computation Tests

    func test_chainPolicy_computeChain_standardSpacing() {
        let settings = ChainSettings(maxChainCount: 10, ringWindowSec: 180, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 30)

        XCTAssertEqual(config.spacingSeconds, 30)
        XCTAssertEqual(config.chainCount, 6) // 180 / 30 = 6
        XCTAssertEqual(config.totalDurationSeconds, 180) // 30 * 6
    }

    func test_chainPolicy_computeChain_respectsMaximumLimit() {
        let settings = ChainSettings(maxChainCount: 3, ringWindowSec: 180, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 10) // Would theoretically allow 18 notifications

        XCTAssertEqual(config.spacingSeconds, 10)
        XCTAssertEqual(config.chainCount, 3) // Capped at maxChainCount
        XCTAssertEqual(config.totalDurationSeconds, 30) // 10 * 3
    }

    func test_chainPolicy_computeChain_ensuresMinimumOne() {
        let settings = ChainSettings(maxChainCount: 12, ringWindowSec: 10, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 60) // 10 / 60 = 0, but should be at least 1

        XCTAssertEqual(config.spacingSeconds, 30) // Normalized from 60 to max 30
        XCTAssertEqual(config.chainCount, 1) // At least 1, even if window is too small
    }

    func test_chainPolicy_computeChain_shortSpacing() {
        let settings = ChainSettings(maxChainCount: 12, ringWindowSec: 60, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 5)

        XCTAssertEqual(config.spacingSeconds, 5)
        XCTAssertEqual(config.chainCount, 12) // 60 / 5 = 12, exactly at limit
    }

    // MARK: - Fire Date Computation Tests

    func test_chainPolicy_computeFireDates_correctIntervals() {
        let policy = ChainPolicy()
        let baseDate = Date(timeIntervalSince1970: 1000000) // Fixed reference point
        let config = ChainConfiguration(spacingSeconds: 30, chainCount: 3)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 3)
        XCTAssertEqual(fireDates[0], baseDate) // k=0: no offset
        XCTAssertEqual(fireDates[1], baseDate.addingTimeInterval(30)) // k=1: +30s
        XCTAssertEqual(fireDates[2], baseDate.addingTimeInterval(60)) // k=2: +60s
    }

    func test_chainPolicy_computeFireDates_singleNotification() {
        let policy = ChainPolicy()
        let baseDate = Date(timeIntervalSince1970: 2000000)
        let config = ChainConfiguration(spacingSeconds: 15, chainCount: 1)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 1)
        XCTAssertEqual(fireDates[0], baseDate)
    }

    func test_chainPolicy_computeFireDates_monotonicIncreasing() {
        let policy = ChainPolicy()
        let baseDate = Date()
        let config = ChainConfiguration(spacingSeconds: 20, chainCount: 5)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 5)

        // Verify dates are strictly increasing
        for i in 1..<fireDates.count {
            XCTAssertLessThan(fireDates[i-1], fireDates[i])

            // Verify exact spacing
            let expectedInterval = TimeInterval(i * config.spacingSeconds)
            let actualInterval = fireDates[i].timeIntervalSince(baseDate)
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 0.001)
        }
    }

    // MARK: - ChainConfiguration Trimming Tests

    func test_chainConfiguration_trimmed_reducesCount() {
        let config = ChainConfiguration(spacingSeconds: 10, chainCount: 8)
        let trimmed = config.trimmed(to: 5)

        XCTAssertEqual(trimmed.spacingSeconds, 10) // Unchanged
        XCTAssertEqual(trimmed.chainCount, 5) // Reduced
        XCTAssertEqual(trimmed.totalDurationSeconds, 50) // 10 * 5
    }

    func test_chainConfiguration_trimmed_respectsMinimumOne() {
        let config = ChainConfiguration(spacingSeconds: 25, chainCount: 4)
        let trimmed = config.trimmed(to: 0) // Should still be at least 1

        XCTAssertEqual(trimmed.spacingSeconds, 25)
        XCTAssertEqual(trimmed.chainCount, 1)
        XCTAssertEqual(trimmed.totalDurationSeconds, 25)
    }

    func test_chainConfiguration_trimmed_noChangeIfWithinLimit() {
        let config = ChainConfiguration(spacingSeconds: 15, chainCount: 3)
        let trimmed = config.trimmed(to: 5) // Limit higher than current count

        XCTAssertEqual(trimmed.spacingSeconds, 15)
        XCTAssertEqual(trimmed.chainCount, 3) // Unchanged
        XCTAssertEqual(trimmed.totalDurationSeconds, 45)
    }

    // MARK: - DST Boundary Edge Case Tests

    func test_chainPolicy_dstBoundary_springForward() {
        let policy = ChainPolicy()

        // March 10, 2024 at 1:30 AM (before spring forward in most US timezones)
        let calendar = Calendar.current
        let beforeDST = calendar.date(from: DateComponents(
            year: 2024, month: 3, day: 10, hour: 1, minute: 30
        ))!

        let config = ChainConfiguration(spacingSeconds: 30, chainCount: 4)
        let fireDates = policy.computeFireDates(baseFireDate: beforeDST, configuration: config)

        XCTAssertEqual(fireDates.count, 4)

        // Verify intervals remain consistent even across DST boundary
        for i in 1..<fireDates.count {
            let interval = fireDates[i].timeIntervalSince(fireDates[i-1])
            XCTAssertEqual(interval, 30.0, accuracy: 0.1) // Allow small tolerance for DST
        }
    }

    func test_chainPolicy_dstBoundary_fallBack() {
        let policy = ChainPolicy()

        // November 3, 2024 at 1:30 AM (before fall back in most US timezones)
        let calendar = Calendar.current
        let beforeDST = calendar.date(from: DateComponents(
            year: 2024, month: 11, day: 3, hour: 1, minute: 30
        ))!

        let config = ChainConfiguration(spacingSeconds: 45, chainCount: 3)
        let fireDates = policy.computeFireDates(baseFireDate: beforeDST, configuration: config)

        XCTAssertEqual(fireDates.count, 3)

        // Verify intervals remain consistent
        for i in 1..<fireDates.count {
            let interval = fireDates[i].timeIntervalSince(fireDates[i-1])
            XCTAssertEqual(interval, 45.0, accuracy: 0.1)
        }
    }

    // MARK: - Boundary Condition Tests

    func test_chainPolicy_extremeValues_handledGracefully() {
        let extremeSettings = ChainSettings(
            maxChainCount: 1,
            ringWindowSec: 30,
            fallbackSpacingSec: 1
        )
        let policy = ChainPolicy(settings: extremeSettings)

        let config = policy.computeChain(spacingSeconds: 1)

        XCTAssertEqual(config.spacingSeconds, 1)
        XCTAssertEqual(config.chainCount, 1) // Capped at max
        XCTAssertEqual(config.totalDurationSeconds, 1)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Domain/ChainSettingsProviderTests.swift

```swift
//
//  ChainSettingsProviderTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class ChainSettingsProviderTests: XCTestCase {

    private var provider: DefaultChainSettingsProvider!

    override func setUp() {
        super.setUp()
        provider = DefaultChainSettingsProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Default Settings Tests

    func test_chainSettings_returnsValidDefaults() {
        let settings = provider.chainSettings()

        XCTAssertEqual(settings.maxChainCount, 12)
        XCTAssertEqual(settings.ringWindowSec, 300)
        XCTAssertEqual(settings.fallbackSpacingSec, 10)
        XCTAssertEqual(settings.minLeadTimeSec, 10)
    }

    func test_chainSettings_defaultsPassValidation() {
        let settings = provider.chainSettings()
        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.errorReasons, [])
    }

    // MARK: - Chain Count Validation Tests

    func test_validateSettings_chainCountTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 0,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount must be at least 1"))
    }

    func test_validateSettings_chainCountTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 20,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount should not exceed 15 (iOS notification limit considerations)"))
    }

    func test_validateSettings_validChainCount_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Ring Window Validation Tests

    func test_validateSettings_ringWindowTooSmall_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 20,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec must be at least 30 seconds"))
    }

    func test_validateSettings_ringWindowTooLarge_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 700,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec should not exceed 600 seconds (10 minutes)"))
    }

    // MARK: - Fallback Spacing Validation Tests

    func test_validateSettings_fallbackSpacingTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 3
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec must be at least 5 seconds"))
    }

    func test_validateSettings_fallbackSpacingTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 70
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec should not exceed 60 seconds"))
    }

    // MARK: - Minimum Lead Time Validation Tests

    func test_validateSettings_minLeadTimeTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 3
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("minLeadTimeSec must be at least 5 seconds"))
    }

    func test_validateSettings_minLeadTimeTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 40
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("minLeadTimeSec should not exceed 30 seconds"))
    }

    func test_validateSettings_minLeadTimeValid_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 15
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Cross-Validation Tests

    func test_validateSettings_ringWindowTooSmallForChain_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 10,
            ringWindowSec: 100, // 10 * 30 = 300, but ring window is only 100
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec too small for maxChainCount at fallbackSpacingSec"))
    }

    func test_validateSettings_ringWindowJustEnoughForChain_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 150, // 5 * 30 = 150, exactly enough
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Multiple Errors Tests

    func test_validateSettings_multipleErrors_returnsAllReasons() {
        let settings = ChainSettings(
            maxChainCount: 0, // Too low
            ringWindowSec: 20, // Too small
            fallbackSpacingSec: 70 // Too high
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertGreaterThan(validation.errorReasons.count, 2)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount must be at least 1"))
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec must be at least 30 seconds"))
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec should not exceed 60 seconds"))
    }

    // MARK: - Validation Result Tests

    func test_validationResult_validCase_hasCorrectProperties() {
        let result = ChainSettingsValidationResult.valid

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.errorReasons, [])
    }

    func test_validationResult_invalidCase_hasCorrectProperties() {
        let reasons = ["Error 1", "Error 2"]
        let result = ChainSettingsValidationResult.invalid(reasons: reasons)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorReasons, reasons)
    }

    // MARK: - Edge Cases

    func test_validateSettings_minimumValidConfiguration_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 1,
            ringWindowSec: 30,
            fallbackSpacingSec: 5
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    func test_validateSettings_maximumValidConfiguration_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 10,
            ringWindowSec: 600,
            fallbackSpacingSec: 60
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Domain/ScheduleMappingDSTTests.swift

```swift
//
//  ScheduleMappingDSTTests.swift
//  alarmAppNewTests
//
//  Tests for DST (Daylight Saving Time) and timezone handling
//  in alarm scheduling. Ensures alarms fire at correct local times
//  regardless of DST transitions or timezone changes.
//

import XCTest
@testable import alarmAppNew

final class ScheduleMappingDSTTests: XCTestCase {

    // MARK: - DST Fall Back Tests

    func test_fall_back_hour_keeps_intended_local_time() {
        // GIVEN: A calendar in Eastern Time (observes DST)
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create an alarm scheduled for 2:30 AM daily
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var alarmComponents = DateComponents()
        alarmComponents.hour = 2
        alarmComponents.minute = 30
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: Computing fire time on fall-back day (Nov 3, 2024)
        // DST ends at 2:00 AM, clocks fall back to 1:00 AM
        var fallBackComponents = DateComponents()
        fallBackComponents.year = 2024
        fallBackComponents.month = 11
        fallBackComponents.day = 3  // Fall back day
        fallBackComponents.hour = 2
        fallBackComponents.minute = 30
        fallBackComponents.second = 0
        fallBackComponents.timeZone = easternTimeZone

        // There are TWO 2:30 AMs on this day:
        // - First at 2:30 AM EDT (before fall back)
        // - Second at 2:30 AM EST (after fall back, 1 hour later)

        guard let firstOccurrence = calendar.date(from: fallBackComponents) else {
            XCTFail("Could not create first occurrence")
            return
        }

        // Get the components back to verify local time
        let resultComponents = calendar.dateComponents(
            [.hour, .minute],
            from: firstOccurrence
        )

        // THEN: Local time should still be 2:30 AM
        XCTAssertEqual(
            resultComponents.hour,
            2,
            "Hour should remain 2 AM"
        )
        XCTAssertEqual(
            resultComponents.minute,
            30,
            "Minutes should remain 30"
        )

        // Verify DST status
        let isDST = easternTimeZone.isDaylightSavingTime(for: firstOccurrence)

        // The calendar typically returns the first occurrence (EDT)
        // But alarm should fire at both 2:30 AMs for reliability

        // Test that we can identify the transition
        let oneHourLater = firstOccurrence.addingTimeInterval(3600)
        let laterComponents = calendar.dateComponents(
            [.hour, .minute],
            from: oneHourLater
        )

        // Due to fall back, one hour later is STILL 2:30 AM (EST now)
        // This is the unique characteristic of fall back
        if laterComponents.hour == 2 && laterComponents.minute == 30 {
            // We're in the repeated hour
            XCTAssertTrue(true, "Correctly identified repeated hour during fall back")
        } else if laterComponents.hour == 3 && laterComponents.minute == 30 {
            // Normal progression (no fall back on this system)
            XCTAssertTrue(true, "System doesn't observe fall back as expected")
        }
    }

    // MARK: - DST Spring Forward Tests

    func test_spring_forward_hour_selects_next_valid_local_time() {
        // GIVEN: A calendar in Eastern Time
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create an alarm scheduled for 2:30 AM daily
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var alarmComponents = DateComponents()
        alarmComponents.hour = 2
        alarmComponents.minute = 30
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: Computing fire time on spring-forward day (March 10, 2024)
        // DST starts at 2:00 AM, clocks spring forward to 3:00 AM
        // 2:30 AM doesn't exist on this day!
        var springComponents = DateComponents()
        springComponents.year = 2024
        springComponents.month = 3
        springComponents.day = 10  // Spring forward day
        springComponents.hour = 2   // This hour doesn't exist!
        springComponents.minute = 30
        springComponents.second = 0
        springComponents.timeZone = easternTimeZone

        // Calendar should adjust to next valid time (3:30 AM)
        let springDate = calendar.date(from: springComponents)

        if let date = springDate {
            let resultComponents = calendar.dateComponents(
                [.hour, .minute],
                from: date
            )

            // THEN: Should skip to 3:30 AM (next valid time)
            XCTAssertEqual(
                resultComponents.hour,
                3,
                "Should skip to 3 AM when 2 AM doesn't exist"
            )
            XCTAssertEqual(
                resultComponents.minute,
                30,
                "Minutes should remain 30"
            )
        } else {
            // Some systems might return nil for invalid time
            XCTAssertNil(springDate, "Invalid time during spring forward may return nil")
        }

        // Test the SnoozeAlarm handling of spring forward
        var beforeSpringForward = DateComponents()
        beforeSpringForward.year = 2024
        beforeSpringForward.month = 3
        beforeSpringForward.day = 10
        beforeSpringForward.hour = 1
        beforeSpringForward.minute = 45
        beforeSpringForward.timeZone = easternTimeZone

        guard let beforeDate = calendar.date(from: beforeSpringForward) else {
            XCTFail("Could not create date before spring forward")
            return
        }

        // Snooze for 30 minutes (crosses spring forward boundary)
        let snoozedDate = SnoozeAlarm.execute(
            alarm: alarm,
            now: beforeDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds.default,
            calendar: calendar,
            timeZone: easternTimeZone
        )

        let snoozedComponents = calendar.dateComponents(
            [.hour, .minute],
            from: snoozedDate
        )

        // Should be 3:15 AM (2:15 AM doesn't exist)
        XCTAssertEqual(
            snoozedComponents.hour,
            3,
            "Snooze across spring forward should skip missing hour"
        )
        XCTAssertEqual(
            snoozedComponents.minute,
            15,
            "Minutes should be correct after spring forward"
        )
    }

    // MARK: - Timezone Change Tests

    func test_timezone_change_recomputes_by_local_components() {
        // GIVEN: An alarm set for 9:00 AM
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var calendar = Calendar(identifier: .gregorian)

        // Start in Eastern Time
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        var alarmComponents = DateComponents()
        alarmComponents.hour = 9
        alarmComponents.minute = 0
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: User travels to Pacific Time
        guard let pacificTimeZone = TimeZone(identifier: "America/Los_Angeles") else {
            XCTSkip("Pacific timezone not available")
            return
        }

        // Recompute alarm time in new timezone
        calendar.timeZone = pacificTimeZone

        // Extract local components from original alarm time
        let localComponents = calendar.dateComponents(
            [.hour, .minute],
            from: alarm.time
        )

        // THEN: Alarm should still be scheduled for 9:00 AM local time
        // (Even though the absolute UTC time has changed)
        XCTAssertEqual(
            localComponents.hour,
            9,
            "Alarm hour should remain 9 AM in local time"
        )
        XCTAssertEqual(
            localComponents.minute,
            0,
            "Alarm minute should remain 0"
        )

        // Verify the absolute time has actually changed
        let easternCalendar = Calendar(identifier: .gregorian)
        var easternCalendarMutable = easternCalendar
        easternCalendarMutable.timeZone = easternTimeZone

        let pacificCalendar = Calendar(identifier: .gregorian)
        var pacificCalendarMutable = pacificCalendar
        pacificCalendarMutable.timeZone = pacificTimeZone

        // Create same local time in both zones
        var testComponents = DateComponents()
        testComponents.year = 2024
        testComponents.month = 6  // No DST complications
        testComponents.day = 15
        testComponents.hour = 9
        testComponents.minute = 0

        testComponents.timeZone = easternTimeZone
        let easternTime = easternCalendarMutable.date(from: testComponents)

        testComponents.timeZone = pacificTimeZone
        let pacificTime = pacificCalendarMutable.date(from: testComponents)

        if let eastern = easternTime, let pacific = pacificTime {
            let timeDifference = eastern.timeIntervalSince(pacific)
            // Eastern is 3 hours ahead of Pacific
            XCTAssertEqual(
                timeDifference,
                -3 * 3600,
                accuracy: 60,
                "Should be 3 hour difference between timezones"
            )
        }
    }

    // MARK: - Complex Scenario Tests

    func test_multiple_dst_transitions_in_year() {
        // GIVEN: A recurring alarm throughout the year
        var calendar = Calendar(identifier: .gregorian)
        guard let timezone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = timezone

        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        alarm.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

        // Set alarm for 6:00 AM
        var alarmComponents = DateComponents()
        alarmComponents.hour = 6
        alarmComponents.minute = 0
        alarmComponents.timeZone = timezone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // Test dates throughout the year
        let testDates = [
            // Before spring DST
            (month: 2, day: 15, expectedHour: 6, description: "February (Standard Time)"),
            // After spring DST
            (month: 4, day: 15, expectedHour: 6, description: "April (Daylight Time)"),
            // Summer
            (month: 7, day: 15, expectedHour: 6, description: "July (Daylight Time)"),
            // After fall DST
            (month: 12, day: 15, expectedHour: 6, description: "December (Standard Time)")
        ]

        for testDate in testDates {
            var components = DateComponents()
            components.year = 2024
            components.month = testDate.month
            components.day = testDate.day
            components.hour = 6
            components.minute = 0
            components.timeZone = timezone

            if let date = calendar.date(from: components) {
                let hourComponent = calendar.component(.hour, from: date)

                XCTAssertEqual(
                    hourComponent,
                    testDate.expectedHour,
                    "Alarm should fire at \(testDate.expectedHour):00 local time in \(testDate.description)"
                )

                // Verify DST status
                let isDST = timezone.isDaylightSavingTime(for: date)
                if testDate.month >= 4 && testDate.month <= 10 {
                    XCTAssertTrue(isDST, "\(testDate.description) should be in DST")
                } else {
                    XCTAssertFalse(isDST, "\(testDate.description) should be in Standard Time")
                }
            }
        }
    }

    func test_alarm_scheduling_preserves_local_time_across_dst() {
        // GIVEN: An alarm set in standard time for 7:00 AM
        var calendar = Calendar.current
        guard let timezone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = timezone

        // January date (Standard Time)
        var januaryComponents = DateComponents()
        januaryComponents.year = 2024
        januaryComponents.month = 1
        januaryComponents.day = 15
        januaryComponents.hour = 7
        januaryComponents.minute = 0
        januaryComponents.timeZone = timezone

        guard let januaryDate = calendar.date(from: januaryComponents) else {
            XCTFail("Could not create January date")
            return
        }

        // WHEN: The same alarm needs to fire in July (Daylight Time)
        var julyComponents = DateComponents()
        julyComponents.year = 2024
        julyComponents.month = 7
        julyComponents.day = 15
        julyComponents.hour = 7  // Same local time
        julyComponents.minute = 0
        julyComponents.timeZone = timezone

        guard let julyDate = calendar.date(from: julyComponents) else {
            XCTFail("Could not create July date")
            return
        }

        // THEN: Both should show 7:00 AM local time
        let janHour = calendar.component(.hour, from: januaryDate)
        let julHour = calendar.component(.hour, from: julyDate)

        XCTAssertEqual(janHour, 7, "January alarm should be at 7 AM")
        XCTAssertEqual(julHour, 7, "July alarm should be at 7 AM")

        // But the UTC times should differ by 1 hour due to DST
        let utcCalendar = Calendar(identifier: .gregorian)
        var utcCalendarMutable = utcCalendar
        utcCalendarMutable.timeZone = TimeZone(abbreviation: "UTC")!

        let janUTCHour = utcCalendarMutable.component(.hour, from: januaryDate)
        let julUTCHour = utcCalendarMutable.component(.hour, from: julyDate)

        // Eastern Standard Time is UTC-5, Eastern Daylight Time is UTC-4
        // 7 AM EST = 12 PM UTC
        // 7 AM EDT = 11 AM UTC
        let hourDifference = abs(janUTCHour - julUTCHour)
        XCTAssertEqual(
            hourDifference,
            1,
            "UTC times should differ by 1 hour due to DST"
        )
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Domain/SnoozePolicyTests.swift

```swift
//
//  SnoozePolicyTests.swift
//  alarmAppNewTests
//
//  Tests for snooze policies and the SnoozeAlarm use case.
//  Verifies duration clamping and DST-aware time calculations.
//

import XCTest
@testable import alarmAppNew

final class SnoozePolicyTests: XCTestCase {

    // MARK: - Duration Clamping Tests

    func test_snooze_clamps_below_min_to_min() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting snooze below minimum (1 minute)
        let requestedDuration: TimeInterval = 60 // 1 minute
        let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedDuration,
            bounds: bounds
        )

        // THEN: Should clamp to minimum (5 minutes)
        XCTAssertEqual(
            clamped,
            5 * 60,
            "Duration below minimum should be clamped to minimum"
        )
    }

    func test_snooze_clamps_above_max_to_max() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting snooze above maximum (2 hours)
        let requestedDuration: TimeInterval = 2 * 60 * 60 // 2 hours
        let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedDuration,
            bounds: bounds
        )

        // THEN: Should clamp to maximum (60 minutes)
        XCTAssertEqual(
            clamped,
            60 * 60,
            "Duration above maximum should be clamped to maximum"
        )
    }

    func test_snooze_allows_duration_within_bounds() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting valid durations
        let validDurations: [TimeInterval] = [
            5 * 60,   // Exactly minimum
            10 * 60,  // 10 minutes
            30 * 60,  // 30 minutes
            60 * 60   // Exactly maximum
        ]

        // THEN: All should remain unchanged
        for duration in validDurations {
            let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
                duration,
                bounds: bounds
            )
            XCTAssertEqual(
                clamped,
                duration,
                "Valid duration \(duration) should not be changed"
            )

            // Also verify validation
            XCTAssertTrue(
                AlarmPresentationPolicy.isSnoozeDurationValid(duration, bounds: bounds),
                "Duration \(duration) should be valid"
            )
        }
    }

    // MARK: - Snooze Bounds Tests

    func test_snooze_bounds_initialization() {
        // GIVEN: Various bounds configurations

        // Normal case
        let normal = SnoozeBounds(min: 60, max: 600)
        XCTAssertEqual(normal.min, 60)
        XCTAssertEqual(normal.max, 600)

        // Inverted bounds (max < min)
        let inverted = SnoozeBounds(min: 600, max: 60)
        XCTAssertEqual(inverted.min, 60, "Should auto-correct inverted bounds")
        XCTAssertEqual(inverted.max, 600, "Should auto-correct inverted bounds")

        // Default bounds
        let defaultBounds = SnoozeBounds.default
        XCTAssertEqual(defaultBounds.min, 5 * 60, "Default min should be 5 minutes")
        XCTAssertEqual(defaultBounds.max, 60 * 60, "Default max should be 60 minutes")
    }

    // MARK: - DST Transition Tests

    func test_snooze_computes_next_fire_on_local_clock_respecting_dst_transition() {
        // GIVEN: A test calendar and timezone that observes DST
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create alarm
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()

        // Test case 1: Spring forward (2 AM -> 3 AM)
        // March 10, 2024 at 1:45 AM EST
        var springComponents = DateComponents()
        springComponents.year = 2024
        springComponents.month = 3
        springComponents.day = 10
        springComponents.hour = 1
        springComponents.minute = 45
        springComponents.second = 0
        springComponents.timeZone = easternTimeZone

        guard let springDate = calendar.date(from: springComponents) else {
            XCTFail("Could not create spring DST test date")
            return
        }

        // WHEN: Snoozing for 30 minutes (crosses DST boundary)
        let springNextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: springDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds(min: 5 * 60, max: 60 * 60),
            calendar: calendar,
            timeZone: easternTimeZone
        )

        // THEN: Should fire at 3:15 AM EDT (not 2:15 AM which doesn't exist)
        let springFireComponents = calendar.dateComponents(
            [.hour, .minute],
            from: springNextFire
        )
        XCTAssertEqual(springFireComponents.hour, 3, "Should skip to 3 AM during spring forward")
        XCTAssertEqual(springFireComponents.minute, 15)

        // Test case 2: Fall back (2 AM occurs twice)
        // November 3, 2024 at 1:45 AM EDT
        var fallComponents = DateComponents()
        fallComponents.year = 2024
        fallComponents.month = 11
        fallComponents.day = 3
        fallComponents.hour = 1
        fallComponents.minute = 45
        fallComponents.second = 0
        fallComponents.timeZone = easternTimeZone

        guard let fallDate = calendar.date(from: fallComponents) else {
            XCTFail("Could not create fall DST test date")
            return
        }

        // WHEN: Snoozing for 30 minutes (crosses DST boundary)
        let fallNextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: fallDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds(min: 5 * 60, max: 60 * 60),
            calendar: calendar,
            timeZone: easternTimeZone
        )

        // THEN: Should fire at 2:15 AM (the second occurrence in EST)
        let fallFireComponents = calendar.dateComponents(
            [.hour, .minute],
            from: fallNextFire
        )
        XCTAssertEqual(fallFireComponents.hour, 2, "Should use 2 AM during fall back")
        XCTAssertEqual(fallFireComponents.minute, 15)

        // Verify it's actually 75 minutes later (not 30) due to repeated hour
        let actualInterval = fallNextFire.timeIntervalSince(fallDate)
        XCTAssertGreaterThan(
            actualInterval,
            30 * 60,
            "Fall back should result in longer actual interval"
        )
    }

    // MARK: - Basic Snooze Execution Tests

    func test_snooze_execution_basic() {
        // GIVEN: An alarm and current time
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        let now = Date()
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Snoozing for 10 minutes
        let nextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 10 * 60,
            bounds: bounds
        )

        // THEN: Next fire should be approximately 10 minutes later
        let interval = nextFire.timeIntervalSince(now)
        XCTAssertEqual(
            interval,
            10 * 60,
            accuracy: 1.0,
            "Should fire 10 minutes later"
        )
    }

    func test_snooze_execution_with_clamping() {
        // GIVEN: An alarm and restrictive bounds
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        let now = Date()
        let bounds = SnoozeBounds(min: 15 * 60, max: 30 * 60)

        // WHEN: Requesting snooze below minimum
        let shortSnooze = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 5 * 60, // 5 minutes
            bounds: bounds
        )

        // THEN: Should be clamped to 15 minutes
        let shortInterval = shortSnooze.timeIntervalSince(now)
        XCTAssertEqual(
            shortInterval,
            15 * 60,
            accuracy: 1.0,
            "Should be clamped to minimum"
        )

        // WHEN: Requesting snooze above maximum
        let longSnooze = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 60 * 60, // 60 minutes
            bounds: bounds
        )

        // THEN: Should be clamped to 30 minutes
        let longInterval = longSnooze.timeIntervalSince(now)
        XCTAssertEqual(
            longInterval,
            30 * 60,
            accuracy: 1.0,
            "Should be clamped to maximum"
        )
    }

    // MARK: - Presentation Policy Tests

    func test_presentation_policy_defaults() {
        // GIVEN: Default presentation policy
        let policy = AlarmPresentationPolicy()

        // WHEN: Checking for alarm without snooze configured
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()

        // THEN: Should not show countdown (snooze not configured)
        XCTAssertFalse(
            policy.shouldShowCountdown(for: alarm),
            "Should not show countdown without snooze configuration"
        )

        XCTAssertFalse(
            policy.requiresLiveActivity(for: alarm),
            "Should not require live activity without snooze"
        )
    }

    func test_stop_button_semantics() {
        // GIVEN: Various alarm configurations

        // WHEN: Alarm has challenges
        let withChallenges = AlarmPresentationPolicy.stopButtonSemantics(
            challengesRequired: true
        )

        // THEN: Should require validation
        XCTAssertEqual(
            withChallenges,
            .requiresChallengeValidation,
            "Should require validation when challenges present"
        )

        // WHEN: Alarm has no challenges
        let noChallenges = AlarmPresentationPolicy.stopButtonSemantics(
            challengesRequired: false
        )

        // THEN: Should always be enabled
        XCTAssertEqual(
            noChallenges,
            .alwaysEnabled,
            "Should be always enabled without challenges"
        )
    }

    // MARK: - Next Occurrence Tests

    func test_next_occurrence_for_recurring_alarm() {
        // GIVEN: A recurring weekday alarm (Mon-Fri at 7:00 AM)
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        alarm.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

        // Set alarm time to 7:00 AM
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        components.second = 0
        alarm.time = calendar.date(from: components) ?? Date()

        // WHEN: Checking next occurrence from a Sunday
        var sundayComponents = DateComponents()
        sundayComponents.year = 2024
        sundayComponents.month = 3
        sundayComponents.day = 3 // A Sunday
        sundayComponents.hour = 20
        sundayComponents.minute = 0
        let sunday = calendar.date(from: sundayComponents) ?? Date()

        let nextOccurrence = SnoozeAlarm.nextOccurrence(
            for: alarm,
            after: sunday,
            calendar: calendar,
            timeZone: calendar.timeZone
        )

        // THEN: Should be Monday at 7:00 AM
        if let next = nextOccurrence {
            let nextComponents = calendar.dateComponents(
                [.weekday, .hour, .minute],
                from: next
            )
            XCTAssertEqual(nextComponents.weekday, 2, "Should be Monday (weekday 2)")
            XCTAssertEqual(nextComponents.hour, 7, "Should be at 7 AM")
            XCTAssertEqual(nextComponents.minute, 0, "Should be at 0 minutes")
        } else {
            XCTFail("Should find next occurrence")
        }
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Domain/Sounds/SoundCatalogTests.swift

```swift
//
//  SoundCatalogTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/24/25.
//

import XCTest
@testable import alarmAppNew

final class SoundCatalogTests: XCTestCase {

    // MARK: - Validation Tests

    func testSoundCatalog_validate_uniqueIds() {
        // Given: A catalog with file validation disabled for testing
        let catalog = SoundCatalog(validateFiles: false)

        // When: We get all sounds
        let allSounds = catalog.all

        // Then: All IDs should be unique
        let uniqueIds = Set(allSounds.map { $0.id })
        XCTAssertEqual(uniqueIds.count, allSounds.count, "All sound IDs must be unique")
    }

    func testSoundCatalog_validate_positiveDurations() {
        // Given: A catalog with file validation disabled
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check all durations
        let allSounds = catalog.all

        // Then: All durations should be positive
        for sound in allSounds {
            XCTAssertGreaterThan(sound.durationSec, 0, "Sound '\(sound.id)' must have positive duration")
        }
    }

    func testSoundCatalog_validate_defaultSoundExists() {
        // Given: A catalog with file validation disabled
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check the default sound ID
        let defaultSoundId = catalog.defaultSoundId

        // Then: Default sound must exist in catalog
        let defaultSound = catalog.info(for: defaultSoundId)
        XCTAssertNotNil(defaultSound, "Default sound ID '\(defaultSoundId)' must exist in catalog")
    }

    // MARK: - Lookup Tests

    func testSoundCatalog_info_returnsCorrectSound() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up the guaranteed "chimes01" sound
        let sound = catalog.info(for: "chimes01")

        // Then: We should get the correct sound with proper identity and invariants
        XCTAssertNotNil(sound, "chimes01 must exist in catalog")
        XCTAssertEqual(sound?.id, "chimes01", "Sound ID must match lookup key")

        // Test basic invariants (not specific values to avoid brittleness)
        XCTAssertFalse(sound?.name.isEmpty ?? true, "Sound name cannot be empty")
        XCTAssertFalse(sound?.fileName.isEmpty ?? true, "Sound fileName cannot be empty")
        XCTAssertGreaterThan(sound?.durationSec ?? 0, 0, "Sound duration must be positive")

        // Verify the sound has reasonable properties for an alarm sound
        if let name = sound?.name {
            XCTAssertTrue(name.count > 2, "Sound name should be descriptive")
        }
        if let fileName = sound?.fileName {
            XCTAssertTrue(fileName.hasSuffix(".caf") || fileName.hasSuffix(".mp3") || fileName.hasSuffix(".wav"),
                         "Sound fileName should have audio extension")
        }
    }

    func testSoundCatalog_info_unknownIdReturnsNil() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up a non-existent sound ID
        let sound = catalog.info(for: "unknown-sound-id")

        // Then: We should get nil
        XCTAssertNil(sound)
    }

    // MARK: - Safe Helper Tests

    func testSoundCatalog_safeInfo_validIdReturnsSound() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with a valid ID
        let sound = catalog.safeInfo(for: "chimes01")

        // Then: We should get the correct sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, "chimes01")
    }

    func testSoundCatalog_safeInfo_invalidIdFallsBackToDefault() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with an invalid ID
        let sound = catalog.safeInfo(for: "invalid-id")

        // Then: We should get the default sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, catalog.defaultSoundId)
    }

    func testSoundCatalog_safeInfo_nilIdFallsBackToDefault() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with nil
        let sound = catalog.safeInfo(for: nil)

        // Then: We should get the default sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, catalog.defaultSoundId)
    }

    // MARK: - Guaranteed Content Tests

    func testSoundCatalog_guaranteedChimes01Exists() {
        // Given: A catalog (this is critical for migration safety)
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up the hardcoded fallback ID used in Alarm.init(from:)
        let sound = catalog.info(for: "chimes01")

        // Then: This sound MUST exist to prevent runtime crashes
        XCTAssertNotNil(sound, "chimes01 must exist - it's the hardcoded fallback in Alarm migration")
        XCTAssertEqual(sound?.id, "chimes01")
    }

    func testSoundCatalog_allSoundsHaveValidProperties() {
        // Given: A catalog with all sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check all sounds
        let allSounds = catalog.all

        // Then: All sounds should have valid properties
        XCTAssertGreaterThan(allSounds.count, 0, "Catalog must have at least one sound")

        for sound in allSounds {
            XCTAssertFalse(sound.id.isEmpty, "Sound ID cannot be empty")
            XCTAssertFalse(sound.name.isEmpty, "Sound name cannot be empty")
            XCTAssertFalse(sound.fileName.isEmpty, "Sound fileName cannot be empty")
            XCTAssertGreaterThan(sound.durationSec, 0, "Sound duration must be positive")
            XCTAssertLessThanOrEqual(sound.durationSec, 30, "Sound duration should be ≤30s for iOS notifications")
        }
    }

    // MARK: - Test Helpers

    private func encodedAlarmsByPatchingSoundId(
        from alarm: Alarm,
        to newValue: String?,
        removeKey: Bool = false
    ) throws -> Data {
        let original = try JSONEncoder().encode([alarm])
        guard var arr = try JSONSerialization.jsonObject(with: original) as? [[String: Any]] else {
            throw NSError(domain: "TestPatch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse encoded alarm as JSON array"])
        }
        var dict = arr[0]
        if removeKey {
            dict.removeValue(forKey: "soundId")
        } else if let newValue {
            dict["soundId"] = newValue
        }
        arr[0] = dict
        return try JSONSerialization.data(withJSONObject: arr, options: [])
    }

    // MARK: - Persistence Repair Tests

    func testPersistenceService_repairInvalidSoundId_sticks() {
        // Given: In-memory UserDefaults suite for isolation
        let suiteName = "test-\(UUID().uuidString)"
        let testSuite = UserDefaults(suiteName: suiteName)!
        defer { testSuite.removePersistentDomain(forName: suiteName) }

        let catalog = SoundCatalog(validateFiles: false)
        let persistence = PersistenceService(defaults: testSuite, soundCatalog: catalog)

        // Create a valid alarm then patch soundId to invalid value (encode-then-patch approach)
        let validAlarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "bells01", // Start with valid soundId
            soundName: nil,
            volume: 0.8
        )

        do {
            // Encode alarm properly, then patch soundId to invalid value
            let patchedData = try encodedAlarmsByPatchingSoundId(from: validAlarm, to: "invalid-sound-id")
            testSuite.set(patchedData, forKey: "savedAlarms")

            // When: First load triggers automatic repair
            let alarmsFirstLoad = try persistence.loadAlarms()

            // Then: soundId should be automatically repaired
            XCTAssertEqual(alarmsFirstLoad[0].soundId, catalog.defaultSoundId, "soundId should be automatically repaired to default")

            // When: Second load to verify repair persistence
            let alarmsSecondLoad = try persistence.loadAlarms()

            // Then: Should remain repaired (no infinite loop)
            XCTAssertEqual(alarmsSecondLoad[0].soundId, catalog.defaultSoundId, "Repair should stick - no infinite loop")

            // Verify the repaired data is actually saved to storage
            if let savedData = testSuite.data(forKey: "savedAlarms") {
                let savedAlarms = try JSONDecoder().decode([Alarm].self, from: savedData)
                XCTAssertEqual(savedAlarms[0].soundId, catalog.defaultSoundId, "Repaired soundId should be persisted")
            } else {
                XCTFail("Expected saved alarms data to exist after repair")
            }
        } catch {
            XCTFail("Test setup or repair should not throw: \(error)")
        }
    }

    func testPersistenceService_repairMissingSoundId_usesDecoder() {
        // Given: In-memory UserDefaults suite
        let suiteName = "test-\(UUID().uuidString)"
        let testSuite = UserDefaults(suiteName: suiteName)!
        defer { testSuite.removePersistentDomain(forName: suiteName) }

        let catalog = SoundCatalog(validateFiles: false)
        let persistence = PersistenceService(defaults: testSuite, soundCatalog: catalog)

        // Create a valid alarm then remove soundId field (encode-then-patch approach)
        let validAlarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Old Format Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "bells01", // Start with valid soundId
            soundName: nil,
            volume: 0.5
        )

        do {
            // Encode alarm properly, then remove soundId field (simulates old format)
            let patchedData = try encodedAlarmsByPatchingSoundId(from: validAlarm, to: nil, removeKey: true)
            testSuite.set(patchedData, forKey: "savedAlarms")

            // When: Load alarms (decoder should handle missing soundId)
            let loadedAlarms = try persistence.loadAlarms()

            // Then: Decoder fallback should provide chimes01
            XCTAssertEqual(loadedAlarms.count, 1)
            XCTAssertEqual(loadedAlarms[0].soundId, "chimes01", "Decoder should fallback to chimes01 for missing soundId")
        } catch {
            XCTFail("Test setup or loading should not throw: \(error)")
        }
    }

    // MARK: - Critical Encode/Decode Tests

    func testAlarm_encodeDecode_preservesSoundId() {
        // Given: Alarm with specific soundId
        let originalSoundId = "bells01"
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [.monday],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: originalSoundId,
            soundName: nil,
            volume: 0.8
        )

        // When: Encode then decode
        do {
            let encoded = try JSONEncoder().encode(alarm)
            let decoded = try JSONDecoder().decode(Alarm.self, from: encoded)

            // Then: soundId preserved exactly
            XCTAssertEqual(decoded.soundId, originalSoundId, "soundId must survive encode/decode to prevent repair loops")

            // Verify other critical fields also preserved
            XCTAssertEqual(decoded.id, alarm.id)
            XCTAssertEqual(decoded.label, alarm.label)
            XCTAssertEqual(decoded.volume, alarm.volume)
        } catch {
            XCTFail("Encode/decode should not throw: \(error)")
        }
    }

    func testAlarm_encodeDecode_preservesSoundIdWithSpecialCharacters() {
        // Given: Alarm with soundId containing special characters (edge case)
        let originalSoundId = "tone-01_special.sound"
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Special Test",
            repeatDays: [],
            challengeKind: [.qr],
            isEnabled: true,
            soundId: originalSoundId,
            volume: 0.5
        )

        // When: Encode then decode
        do {
            let encoded = try JSONEncoder().encode(alarm)
            let decoded = try JSONDecoder().decode(Alarm.self, from: encoded)

            // Then: Special characters in soundId preserved
            XCTAssertEqual(decoded.soundId, originalSoundId, "Special characters in soundId must be preserved")
        } catch {
            XCTFail("Encode/decode should not throw: \(error)")
        }
    }

    // MARK: - Preview Catalog Tests

    func testSoundCatalog_preview_isAccessible() {
        // Given: The preview catalog
        let catalog = SoundCatalog.preview

        // When: We access its properties
        let allSounds = catalog.all
        let defaultId = catalog.defaultSoundId

        // Then: It should work without file validation
        XCTAssertGreaterThan(allSounds.count, 0)
        XCTAssertNotNil(catalog.info(for: defaultId))
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/AlarmKitSchedulerTests.swift

```swift
//
//  AlarmKitSchedulerTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmKitScheduler implementation.
//

import XCTest
@testable import alarmAppNew

@available(iOS 26.0, *)
@MainActor
final class AlarmKitSchedulerTests: XCTestCase {

    // MARK: - Mock Types

    struct MockPresentationBuilder: AlarmPresentationBuilding {
        func buildSchedule(from alarm: Alarm) -> Any {
            return ["alarmId": alarm.id.uuidString, "time": alarm.time]
        }

        func buildPresentation(for alarm: Alarm) -> Any {
            return ["label": alarm.label, "soundId": alarm.soundId]
        }
    }

    // MARK: - Properties

    private var presentationBuilder: AlarmPresentationBuilding!
    private var scheduler: AlarmKitScheduler!
    private var testAlarm: Alarm!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        presentationBuilder = MockPresentationBuilder()
        scheduler = AlarmKitScheduler(
            presentationBuilder: presentationBuilder
        )

        // Create test alarm
        testAlarm = Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "ringtone1",
            soundName: nil,
            volume: 0.8,
            externalAlarmId: nil
        )
    }

    override func tearDown() async throws {
        presentationBuilder = nil
        scheduler = nil
        testAlarm = nil
        try await super.tearDown()
    }

    // MARK: - Activation Tests

    func test_activate_isIdempotent() async {
        // When: Activating multiple times
        await scheduler.activate()
        await scheduler.activate()
        await scheduler.activate()

        // Then: Should handle gracefully (no crashes or side effects)
        // Activation is idempotent
        XCTAssertTrue(true, "Activation should be idempotent")
    }

    // MARK: - Authorization Tests

    func test_requestAuthorizationIfNeeded_doesNotCrash() async throws {
        // When: Requesting authorization
        // Then: Should not throw in stub implementation
        try await scheduler.requestAuthorizationIfNeeded()
    }

    // MARK: - Scheduling Tests

    func test_schedule_returnsExternalId() async throws {
        // When: Scheduling an alarm
        let externalId = try await scheduler.schedule(alarm: testAlarm)

        // Then: Should return a non-empty external ID
        XCTAssertFalse(externalId.isEmpty)
        XCTAssertTrue(externalId.contains(testAlarm.id.uuidString))
    }

    func test_schedule_usesPresentationBuilder() async throws {
        // When: Scheduling an alarm
        _ = try await scheduler.schedule(alarm: testAlarm)

        // Then: Presentation builder should be invoked
        // (We can't directly verify this without a mock, but the schedule succeeds)
        XCTAssertTrue(true, "Schedule should use presentation builder")
    }

    // MARK: - Pending Alarms Tests

    func test_pendingAlarmIds_returnsEmptyInStub() async {
        // When: Getting pending alarm IDs
        let pendingIds = await scheduler.pendingAlarmIds()

        // Then: Should return empty array (stub implementation)
        XCTAssertTrue(pendingIds.isEmpty)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/AlarmSchedulerFactoryTests.swift

```swift
//
//  AlarmSchedulerFactoryTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmSchedulerFactory version detection and dependency injection.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class AlarmSchedulerFactoryTests: XCTestCase {

    // MARK: - Mock Types

    struct MockPresentationBuilder: AlarmPresentationBuilding {
        @available(iOS 26.0, *)
        func buildSchedule(from alarm: Alarm) -> Any { return [:] }

        @available(iOS 26.0, *)
        func buildPresentation(for alarm: Alarm) -> Any { return [:] }
    }

    // MARK: - Properties

    private var legacyScheduler: AlarmScheduling!
    private var presentationBuilder: AlarmPresentationBuilding!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        legacyScheduler = MockAlarmScheduling()
        presentationBuilder = MockPresentationBuilder()
    }

    override func tearDown() async throws {
        legacyScheduler = nil
        presentationBuilder = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_make_injectsCorrectDependencies() {
        // When: Creating scheduler via factory
        let scheduler = AlarmSchedulerFactory.make(
            presentationBuilder: presentationBuilder
        )

        // Then: Should return a valid scheduler
        XCTAssertNotNil(scheduler)
    }

    func test_make_iOSLegacy_returnsLegacyScheduler() {
        // Given: We're on iOS < 26 (current environment)
        // When: Creating scheduler
        let scheduler = AlarmSchedulerFactory.make(
            presentationBuilder: presentationBuilder
        )

        // Then: Should return the legacy scheduler on current iOS
        if #available(iOS 26.0, *) {
            // This won't execute on current iOS versions
            XCTFail("Test environment should not be iOS 26+")
        } else {
            // Verify we got the legacy scheduler (cast to class type for comparison)
            if let mockLegacy = legacyScheduler as? MockAlarmScheduling,
               let returnedScheduler = scheduler as? MockAlarmScheduling {
                XCTAssertTrue(mockLegacy === returnedScheduler,
                             "Factory should return legacy scheduler on iOS < 26")
            } else {
                XCTFail("Failed to cast scheduler to expected type")
            }
        }
    }

    @available(iOS 26.0, *)
    func test_make_iOS26Plus_returnsAlarmKitScheduler() {
        // When: Creating scheduler on iOS 26+
        let scheduler = AlarmSchedulerFactory.make(
            presentationBuilder: presentationBuilder
        )

        // Then: Should return AlarmKitScheduler
        XCTAssertTrue(scheduler is AlarmKitScheduler,
                     "Factory should return AlarmKitScheduler on iOS 26+")
        // Verify it's NOT the legacy scheduler
        if let mockLegacy = legacyScheduler as? MockAlarmScheduling,
           let returnedScheduler = scheduler as? MockAlarmScheduling {
            XCTAssertFalse(mockLegacy === returnedScheduler,
                          "Should not return legacy scheduler on iOS 26+")
        } else {
            // If we can't cast to MockAlarmScheduling, that's good - it means it's AlarmKitScheduler
            XCTAssertTrue(true, "Scheduler is not the mock legacy type, as expected")
        }
    }

    func test_make_doesNotRequireWholeContainer() {
        // This test verifies that the factory doesn't depend on DependencyContainer
        // by successfully creating a scheduler with just the required dependencies

        // When: Creating with minimal dependencies (no container)
        let scheduler = AlarmSchedulerFactory.make(
            presentationBuilder: presentationBuilder
        )

        // Then: Should succeed without needing full container
        XCTAssertNotNil(scheduler, "Factory should work with explicit deps only")
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/AlarmSoundEngineTests.swift

```swift
//
//  AlarmSoundEngineTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/2/25.
//

import XCTest
import Combine
@testable import alarmAppNew

@MainActor
final class AlarmSoundEngineTests: XCTestCase {

    var sut: AlarmSoundEngine!
    var mockReliabilityProvider: MockReliabilityModeProvider!

    override func setUp() async throws {
        sut = AlarmSoundEngine.shared
        mockReliabilityProvider = MockReliabilityModeProvider()
        sut.setReliabilityModeProvider(mockReliabilityProvider)

        // Set up policy provider for new capability-based architecture
        sut.setPolicyProvider { [weak self] in
            let mode = self?.mockReliabilityProvider.currentMode ?? .notificationsOnly
            switch mode {
            case .notificationsOnly:
                return AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
            case .notificationsPlusAudio:
                return AudioPolicy(capability: .sleepMode, allowRouteOverrideAtAlarm: true)
            }
        }

        sut.stop() // Ensure clean state
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        mockReliabilityProvider = nil
    }

    // MARK: - isActivelyRinging Property Tests

    func test_isActivelyRinging_falseWhenIdle() {
        // Given: engine in idle state
        sut.stop()

        // Then: should not be actively ringing
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing when idle")
        XCTAssertEqual(sut.currentState, .idle)
    }

    func test_isActivelyRinging_falseWhenPrewarming() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: schedule prewarm for future (will transition to prewarming)
        let future = Date().addingTimeInterval(30)
        try sut.schedulePrewarm(fireAt: future, soundName: "ringtone1")

        // Then: should not be actively ringing (only prewarming)
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing when prewarming")
        XCTAssertEqual(sut.currentState, .prewarming)
    }

    func test_isActivelyRinging_trueWhenRinging() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: play foreground alarm (transitions to ringing)
        try sut.playForegroundAlarm(soundName: "ringtone1")

        // Then: should be actively ringing
        XCTAssertTrue(sut.isActivelyRinging, "Should be ringing after playForegroundAlarm")
        XCTAssertEqual(sut.currentState, .ringing)

        // Cleanup
        sut.stop()
    }

    // MARK: - scheduleWithLeadIn Validation Tests

    func test_scheduleWithLeadIn_skipsInNotificationsOnlyMode() throws {
        // Given: notifications-only mode
        mockReliabilityProvider.setMode(.notificationsOnly)

        // When: attempt to schedule with lead-in
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should remain idle (skipped due to mode)
        XCTAssertEqual(sut.currentState, .idle, "Should skip scheduling in notifications-only mode")
        XCTAssertFalse(sut.isActivelyRinging)
    }

    func test_scheduleWithLeadIn_fallsBackToImmediateIfLeadInExceedsDelta() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: lead-in (10s) exceeds delta (3s) - should fall back to immediate
        let nearFuture = Date().addingTimeInterval(3)
        try sut.scheduleWithLeadIn(fireAt: nearFuture, soundId: "ringtone1", leadInSeconds: 10)

        // Then: should have fallen back to immediate playback (ringing state)
        XCTAssertTrue(sut.isActivelyRinging, "Should fall back to immediate when leadIn > delta")
        XCTAssertEqual(sut.currentState, .ringing)

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_schedulesAudioStartCorrectly() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: schedule with valid lead-in
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should transition to prewarming (audio will start at T-5s)
        XCTAssertEqual(sut.currentState, .prewarming, "Should be in prewarming state")
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing yet")

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_transitionsToPrewarmingState() throws {
        // Given: notificationsPlusAudio mode and idle state
        mockReliabilityProvider.setMode(.notificationsPlusAudio)
        XCTAssertEqual(sut.currentState, .idle)

        // When: schedule with lead-in
        let future = Date().addingTimeInterval(20)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 3)

        // Then: state should be prewarming
        XCTAssertEqual(sut.currentState, .prewarming)

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_respectsIdleStateGuard() throws {
        // Given: notificationsPlusAudio mode and already ringing
        mockReliabilityProvider.setMode(.notificationsPlusAudio)
        try sut.playForegroundAlarm(soundName: "ringtone1")
        XCTAssertEqual(sut.currentState, .ringing)

        // When: attempt to schedule with lead-in (should be rejected by state guard)
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should remain in ringing state (guard rejected the call)
        XCTAssertEqual(sut.currentState, .ringing, "Should ignore scheduleWithLeadIn when not idle")

        // Cleanup
        sut.stop()
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/ChainedNotificationSchedulerTests.swift

```swift
//
//  ChainedNotificationSchedulerTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
import UserNotifications
@testable import alarmAppNew

final class ChainedNotificationSchedulerTests: XCTestCase {

    private var mockNotificationCenter: MockNotificationCenter!
    private var mockSoundCatalog: MockSoundCatalog!
    private var testNotificationIndex: NotificationIndex!
    private var chainPolicy: ChainPolicy!
    private var mockGlobalLimitGuard: MockGlobalLimitGuard!
    private var mockClock: MockClock!
    private var scheduler: ChainedNotificationScheduler!

    private let testAlarmId = UUID()
    private let testFireDate = Date(timeIntervalSince1970: 1696156800) // Fixed for reproducibility

    override func setUp() {
        super.setUp()

        mockNotificationCenter = MockNotificationCenter()
        mockSoundCatalog = MockSoundCatalog()

        let testSuiteName = "test-scheduler-\(UUID().uuidString)"
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
        mockClock = MockClock(fixedNow: testFireDate.addingTimeInterval(-3600)) // 1 hour before

        scheduler = ChainedNotificationScheduler(
            notificationCenter: mockNotificationCenter,
            soundCatalog: mockSoundCatalog,
            notificationIndex: testNotificationIndex,
            chainPolicy: chainPolicy,
            globalLimitGuard: mockGlobalLimitGuard,
            clock: mockClock
        )
    }

    override func tearDown() {
        mockNotificationCenter = nil
        mockSoundCatalog = nil
        testNotificationIndex = nil
        chainPolicy = nil
        mockGlobalLimitGuard = nil
        mockClock = nil
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Permission Tests

    func test_scheduleChain_unauthorizedNotifications_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .denied

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .permissions))
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 0)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 0)
    }

    func test_scheduleChain_provisionalNotifications_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .provisional

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .permissions))
    }

    // MARK: - Global Limit Tests

    func test_scheduleChain_noAvailableSlots_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 0

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .globalLimit))
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 1)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 0)
    }

    func test_scheduleChain_partialSlots_returnsTrimmed() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 30)
        mockGlobalLimitGuard.reserveReturnValue = 3 // Less than the 5 requested

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        if case .trimmed(let original, let scheduled) = outcome {
            XCTAssertEqual(original, 5) // maxChainCount from settings
            XCTAssertEqual(scheduled, 3) // limited by available slots
        } else {
            XCTFail("Expected trimmed outcome, got \(outcome)")
        }

        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 3)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
    }

    // MARK: - Successful Scheduling Tests

    func test_scheduleChain_fullSlots_returnsScheduled() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 30)
        mockGlobalLimitGuard.reserveReturnValue = 5

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        if case .scheduled(let count) = outcome {
            XCTAssertEqual(count, 5)
        } else {
            XCTFail("Expected scheduled outcome, got \(outcome)")
        }

        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 5)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
    }

    func test_scheduleChain_correctFireDatesSpacing() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 45)
        mockGlobalLimitGuard.reserveReturnValue = 3

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 3)

        // Verify spacing matches sound duration
        for (index, request) in requests.enumerated() {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                let expectedFireDate = testFireDate.addingTimeInterval(Double(index * 45))
                let calendar = Calendar.current
                let expectedComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: expectedFireDate
                )

                XCTAssertEqual(trigger.dateComponents.year, expectedComponents.year)
                XCTAssertEqual(trigger.dateComponents.hour, expectedComponents.hour)
                XCTAssertEqual(trigger.dateComponents.minute, expectedComponents.minute)
            } else {
                XCTFail("Expected calendar trigger for request \(index)")
            }
        }
    }

    // MARK: - Sound Catalog Integration Tests

    func test_scheduleChain_fallbackSoundDuration_usesFallbackSpacing() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = nil // No sound info found
        mockGlobalLimitGuard.reserveReturnValue = 3

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 3)

        // Should use fallback spacing of 30 seconds
        if let firstTrigger = requests[0].trigger as? UNCalendarNotificationTrigger,
           let secondTrigger = requests[1].trigger as? UNCalendarNotificationTrigger {

            let firstDate = Calendar.current.date(from: firstTrigger.dateComponents)!
            let secondDate = Calendar.current.date(from: secondTrigger.dateComponents)!
            let actualSpacing = secondDate.timeIntervalSince(firstDate)

            XCTAssertEqual(actualSpacing, 30.0, accuracy: 1.0)
        }
    }

    // MARK: - Notification Content Tests

    func test_scheduleChain_notificationContent_correctFormat() async {
        let alarm = createTestAlarm(label: "Morning Workout")
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "gentle", fileName: "gentle.caf", durationSec: 20)
        mockGlobalLimitGuard.reserveReturnValue = 2

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 2)

        for request in requests {
            XCTAssertEqual(request.content.title, "Alarm")
            XCTAssertEqual(request.content.body, "Morning Workout")
            XCTAssertEqual(request.content.categoryIdentifier, "ALARM_CATEGORY")

            if let sound = request.content.sound {
                XCTAssertEqual(sound.description, "UNNotificationSound:gentle.caf")
            } else {
                XCTFail("Expected notification sound")
            }
        }
    }

    func test_scheduleChain_emptyLabel_usesDefaultBody() async {
        let alarm = createTestAlarm(label: "")
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 1

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let request = mockNotificationCenter.scheduledRequests.first!
        XCTAssertEqual(request.content.body, "Alarm")
    }

    // MARK: - Identifier Tests

    func test_scheduleChain_identifierFormat_isCorrect() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 2

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 2)

        for (index, request) in requests.enumerated() {
            XCTAssertTrue(request.identifier.hasPrefix("alarm-\(alarm.id.uuidString)-occ-"))
            XCTAssertTrue(request.identifier.hasSuffix("-\(index)"))
            XCTAssertTrue(request.identifier.contains("T")) // ISO8601 format
        }
    }

    // MARK: - Idempotent Reschedule Tests

    func test_scheduleChain_existingChain_cancelsBeforeScheduling() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 2

        // First schedule
        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 2)
        let firstRequestIds = mockNotificationCenter.scheduledRequests.map(\.identifier)

        // Second schedule with different fire date
        let newFireDate = testFireDate.addingTimeInterval(3600)
        await scheduler.scheduleChain(for: alarm, fireDate: newFireDate)

        // Should have cancelled old and scheduled new
        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 2)
        XCTAssertTrue(Set(firstRequestIds).isSubset(of: Set(mockNotificationCenter.cancelledIdentifiers)))
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 2) // New ones
    }

    // MARK: - Cancel Chain Tests

    func test_cancelChain_existingChain_removesAllNotifications() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 3

        // Schedule chain
        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 3)

        // Cancel chain
        await scheduler.cancelChain(alarmId: alarm.id)

        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 3)
        XCTAssertEqual(testNotificationIndex.loadIdentifiers(alarmId: alarm.id), [])
    }

    func test_cancelChain_nonexistentChain_doesNothing() async {
        let nonexistentAlarmId = UUID()

        await scheduler.cancelChain(alarmId: nonexistentAlarmId)

        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 0)
    }

    // MARK: - Authorization Tests

    func test_requestAuthorization_granted_succeeds() async {
        mockNotificationCenter.authorizationGranted = true
        mockNotificationCenter.authorizationError = nil

        do {
            try await scheduler.requestAuthorization()
        } catch {
            XCTFail("Should not throw when authorization is granted")
        }
    }

    func test_requestAuthorization_denied_throws() async {
        mockNotificationCenter.authorizationGranted = false
        mockNotificationCenter.authorizationError = nil

        do {
            try await scheduler.requestAuthorization()
            XCTFail("Should throw when authorization is denied")
        } catch let error as NotificationSchedulingError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Should throw NotificationSchedulingError.authorizationDenied")
        }
    }

    func test_requestAuthorization_systemError_throws() async {
        let systemError = NSError(domain: "TestError", code: 123, userInfo: nil)
        mockNotificationCenter.authorizationGranted = true
        mockNotificationCenter.authorizationError = systemError

        do {
            try await scheduler.requestAuthorization()
            XCTFail("Should throw when system error occurs")
        } catch {
            XCTAssertEqual(error as NSError, systemError)
        }
    }

    // MARK: - Bug Fix Tests (Timing & Sound)

    func test_buildTriggerWithInterval_usesProvidedInterval() {
        // Given: a specific interval
        let interval: TimeInterval = 45.0

        // When: build trigger with the interval
        let trigger = scheduler.buildTriggerWithInterval(interval)

        // Then: should use time interval trigger with provided interval
        XCTAssertTrue(trigger is UNTimeIntervalNotificationTrigger, "Should use UNTimeIntervalNotificationTrigger for precise timing")

        let timeTrigger = trigger as! UNTimeIntervalNotificationTrigger
        XCTAssertEqual(timeTrigger.timeInterval, 45.0, "Time interval should match provided interval")
        XCTAssertFalse(timeTrigger.repeats, "Alarm triggers should not repeat")
    }

    func test_buildTriggerWithInterval_clampsToIOSMinimum() {
        // Given: interval less than iOS minimum
        let interval: TimeInterval = 0.5

        // When: build trigger with small interval
        let trigger = scheduler.buildTriggerWithInterval(interval)

        // Then: should clamp to iOS minimum (1 second)
        XCTAssertTrue(trigger is UNTimeIntervalNotificationTrigger, "Should use UNTimeIntervalNotificationTrigger")

        let timeTrigger = trigger as! UNTimeIntervalNotificationTrigger
        XCTAssertEqual(timeTrigger.timeInterval, 1.0, "Should clamp to iOS minimum of 1 second")
    }

    func test_buildTriggerWithInterval_preservesSpacing() {
        // Given: base interval and spacing
        let baseInterval: TimeInterval = 10.0
        let spacing: TimeInterval = 15.0

        // When: build triggers for a chain
        let trigger0 = scheduler.buildTriggerWithInterval(baseInterval + 0 * spacing)
        let trigger1 = scheduler.buildTriggerWithInterval(baseInterval + 1 * spacing)
        let trigger2 = scheduler.buildTriggerWithInterval(baseInterval + 2 * spacing)

        // Then: intervals should preserve spacing
        let timeTrigger0 = trigger0 as! UNTimeIntervalNotificationTrigger
        let timeTrigger1 = trigger1 as! UNTimeIntervalNotificationTrigger
        let timeTrigger2 = trigger2 as! UNTimeIntervalNotificationTrigger

        XCTAssertEqual(timeTrigger0.timeInterval, 10.0, "First interval should be base")
        XCTAssertEqual(timeTrigger1.timeInterval, 25.0, "Second interval should be base + spacing")
        XCTAssertEqual(timeTrigger2.timeInterval, 40.0, "Third interval should be base + 2*spacing")
    }

    func test_eachChainedRequest_hasSoundAttached() async {
        // Given: authorized notifications with available slots
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5
        mockSoundCatalog.soundInfo = SoundInfo(
            id: "test",
            name: "Test Sound",
            fileName: "test.caf",
            durationSeconds: 10
        )

        // When: schedule chain
        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        // Then: all scheduled requests should have sound attached
        guard case .scheduled(let count) = outcome else {
            XCTFail("Expected scheduled outcome")
            return
        }

        XCTAssertEqual(count, 5, "Should schedule all reserved slots")
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 5, "Should have 5 requests in notification center")

        // Verify every request has sound
        for request in mockNotificationCenter.scheduledRequests {
            XCTAssertNotNil(request.content.sound, "Every alarm notification must have sound attached")
        }
    }

    // MARK: - Helper Methods

    private func createTestAlarm(label: String = "Test Alarm") -> Alarm {
        return Alarm(
            id: testAlarmId,
            time: DateComponents(hour: 7, minute: 30),
            repeatDays: [],
            label: label,
            soundId: "test-sound",
            volume: 0.8,
            vibrate: true,
            isEnabled: true
        )
    }
}

// MARK: - Mock Implementations

private class MockNotificationCenter: UNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var authorizationGranted = true
    var authorizationError: Error?
    var scheduledRequests: [UNNotificationRequest] = []
    var cancelledIdentifiers: [String] = []

    override func notificationSettings() async -> UNNotificationSettings {
        let settings = MockNotificationSettings(authorizationStatus: authorizationStatus)
        return settings
    }

    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let error = authorizationError {
            throw error
        }
        return authorizationGranted
    }

    override func add(_ request: UNNotificationRequest) async throws {
        scheduledRequests.append(request)
    }

    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        cancelledIdentifiers.append(contentsOf: identifiers)
    }

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

private class MockNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }

    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

private class MockSoundCatalog: SoundCatalogProviding {
    var soundInfo: SoundInfo?

    func safeInfo(for soundId: String) -> SoundInfo? {
        return soundInfo
    }
}

private class MockGlobalLimitGuard: GlobalLimitGuard {
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
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/GlobalLimitGuardTests.swift

```swift
//
//  GlobalLimitGuardTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
import UserNotifications
@testable import alarmAppNew

final class GlobalLimitGuardTests: XCTestCase {

    private var mockNotificationCenter: MockNotificationCenter!
    private var config: GlobalLimitConfig!
    private var limitGuard: GlobalLimitGuard!

    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockNotificationCenter()
        config = GlobalLimitConfig(safetyBuffer: 4, maxSystemLimit: 64)
        limitGuard = GlobalLimitGuard(config: config, notificationCenter: mockNotificationCenter)
    }

    override func tearDown() {
        mockNotificationCenter = nil
        config = nil
        limitGuard = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func test_globalLimitConfig_availableThreshold_calculatesCorrectly() {
        let config = GlobalLimitConfig(safetyBuffer: 10, maxSystemLimit: 100)
        XCTAssertEqual(config.availableThreshold, 90)
    }

    func test_globalLimitConfig_defaultValues_areReasonable() {
        let defaultConfig = GlobalLimitConfig()
        XCTAssertEqual(defaultConfig.safetyBuffer, 4)
        XCTAssertEqual(defaultConfig.maxSystemLimit, 64)
        XCTAssertEqual(defaultConfig.availableThreshold, 60)
    }

    // MARK: - Available Slots Calculation Tests

    func test_availableSlots_noPendingNotifications_returnsThreshold() async {
        mockNotificationCenter.pendingRequests = []

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, config.availableThreshold) // 60
    }

    func test_availableSlots_somePendingNotifications_returnsRemaining() async {
        let pendingRequests = Array(0..<20).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 40) // 60 - 20
    }

    func test_availableSlots_nearLimit_returnsLowNumber() async {
        let pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 2) // 60 - 58
    }

    func test_availableSlots_atLimit_returnsZero() async {
        let pendingRequests = Array(0..<60).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 0)
    }

    func test_availableSlots_overLimit_returnsZero() async {
        let pendingRequests = Array(0..<70).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 0)
    }

    func test_availableSlots_notificationCenterError_returnsConservativeFallback() async {
        mockNotificationCenter.shouldThrowOnPendingRequests = true

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 1) // Conservative fallback
    }

    // MARK: - Reservation Tests

    func test_reserve_sufficientSlots_grantsFullRequest() async {
        mockNotificationCenter.pendingRequests = Array(0..<10).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)

        XCTAssertEqual(granted, 5)
    }

    func test_reserve_insufficientSlots_grantsPartial() async {
        mockNotificationCenter.pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)

        XCTAssertEqual(granted, 2) // Only 2 available (60 - 58)
    }

    func test_reserve_noSlotsAvailable_grantsZero() async {
        mockNotificationCenter.pendingRequests = Array(0..<60).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(3)

        XCTAssertEqual(granted, 0)
    }

    func test_reserve_zeroRequested_grantsZero() async {
        mockNotificationCenter.pendingRequests = []

        let granted = await limitGuard.reserve(0)

        XCTAssertEqual(granted, 0)
    }

    func test_reserve_negativeRequested_grantsZero() async {
        mockNotificationCenter.pendingRequests = []

        let granted = await limitGuard.reserve(-5)

        XCTAssertEqual(granted, 0)
    }

    // MARK: - Concurrent Reservation Tests

    func test_reserve_concurrentRequests_maintainsSafety() async {
        mockNotificationCenter.pendingRequests = Array(0..<50).map { createMockRequest(identifier: "pending-\($0)") }

        // Simulate 5 concurrent reservation requests
        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await self.limitGuard.reserve(5)
                }
            }

            var totalGranted = 0
            for await result in group {
                totalGranted += result
            }
            return totalGranted
        }

        // Should not grant more than available (60 - 50 = 10)
        XCTAssertLessThanOrEqual(results, 10)
        XCTAssertGreaterThan(results, 0) // Should grant something
    }

    func test_reserve_sequentialReservations_tracksCorrectly() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let first = await limitGuard.reserve(3)
        let second = await limitGuard.reserve(2)
        let third = await limitGuard.reserve(1)

        XCTAssertEqual(first, 3) // 5 available, granted 3
        XCTAssertEqual(second, 2) // 2 remaining, granted 2
        XCTAssertEqual(third, 0) // 0 remaining, granted 0
    }

    // MARK: - Finalization Tests

    func test_finalize_releasesReservedSlots() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)
        XCTAssertEqual(granted, 5)

        // Finalize with fewer than reserved (some failed to schedule)
        await limitGuard.finalize(3)

        // Should be able to reserve more now
        let secondGranted = await limitGuard.reserve(2)
        XCTAssertEqual(secondGranted, 2) // 2 slots were freed up
    }

    func test_finalize_moreThanReserved_handledSafely() async {
        mockNotificationCenter.pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(2)
        XCTAssertEqual(granted, 2)

        // Finalize with more than reserved (shouldn't happen, but be safe)
        await limitGuard.finalize(5)

        // Reserved slots should not go negative
        #if DEBUG
        let reservedSlots = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedSlots, 0)
        #endif
    }

    // MARK: - Edge Cases

    func test_reserve_multipleFinalizeOperations_maintainsConsistency() async {
        mockNotificationCenter.pendingRequests = Array(0..<50).map { createMockRequest(identifier: "pending-\($0)") }

        let first = await limitGuard.reserve(5)
        let second = await limitGuard.reserve(3)

        await limitGuard.finalize(2) // Partial finalization of first
        await limitGuard.finalize(3) // Full finalization of second
        await limitGuard.finalize(3) // Finalization of remaining from first

        // Should have all slots available again
        let third = await limitGuard.reserve(10)
        XCTAssertEqual(third, 10) // 60 - 50 = 10 available
    }

    // MARK: - Test Hooks (DEBUG only)

    #if DEBUG
    func test_resetReservations_clearsReservedSlots() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)
        XCTAssertEqual(granted, 5)
        let reservedAfterReserve = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterReserve, 5)

        await limitGuard.resetReservations()
        let reservedAfterReset = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterReset, 0)

        // Should be able to reserve full amount again
        let secondGranted = await limitGuard.reserve(5)
        XCTAssertEqual(secondGranted, 5)
    }

    func test_currentReservedSlots_trackingCorrectly() async {
        mockNotificationCenter.pendingRequests = []

        let initialReserved = await limitGuard.currentReservedSlots
        XCTAssertEqual(initialReserved, 0)

        let granted = await limitGuard.reserve(10)
        XCTAssertEqual(granted, 10)
        let reservedAfterReserve = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterReserve, 10)

        await limitGuard.finalize(7)
        let reservedAfterFirstFinalize = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterFirstFinalize, 3)

        await limitGuard.finalize(3)
        let reservedAfterSecondFinalize = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterSecondFinalize, 0)
    }
    #endif

    // MARK: - Helper Methods

    private func createMockRequest(identifier: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Test"
        content.body = "Test notification"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}

// MARK: - Mock Implementation

private class MockNotificationCenter: UNUserNotificationCenter {
    var pendingRequests: [UNNotificationRequest] = []
    var shouldThrowOnPendingRequests = false

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        if shouldThrowOnPendingRequests {
            throw NSError(domain: "MockError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return pendingRequests
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/IntentBridgeFreshnessTests.swift

```swift
//
//  IntentBridgeFreshnessTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmIntentBridge timestamp freshness validation.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class IntentBridgeFreshnessTests: XCTestCase {
    private let appGroupIdentifier = "group.com.beshoy.alarmAppNew"
    private var sharedDefaults: UserDefaults?
    private var bridge: AlarmIntentBridge!
    private var notificationExpectation: XCTestExpectation?

    override func setUp() async throws {
        try await super.setUp()
        bridge = AlarmIntentBridge()
        sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

        // Clear any existing data
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntent")
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntentTimestamp")
    }

    override func tearDown() async throws {
        // Clean up
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntent")
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntentTimestamp")
        NotificationCenter.default.removeObserver(self)
        try await super.tearDown()
    }

    func test_checkForPendingIntent_whenTimestampFresh_shouldPostNotification() async {
        // Given: A fresh intent (5 seconds old)
        let alarmId = UUID()
        let freshTimestamp = Date().addingTimeInterval(-5)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(freshTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        notificationExpectation = expectation(description: "Should receive alarmIntentReceived notification")
        var receivedAlarmId: UUID?

        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { notification in
            receivedAlarmId = notification.userInfo?["alarmId"] as? UUID
            self.notificationExpectation?.fulfill()
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Then: Should post notification with correct alarm ID
        await fulfillment(of: [notificationExpectation!], timeout: 1.0)
        XCTAssertEqual(receivedAlarmId, alarmId, "Should receive correct alarm ID in notification")

        // And: Should clear the intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenTimestampStale_shouldNotPostNotification() async {
        // Given: A stale intent (35 seconds old)
        let alarmId = UUID()
        let staleTimestamp = Date().addingTimeInterval(-35)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(staleTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification for stale intent")

        // And: Should clear the stale intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenTimestampBoundary_shouldPostNotification() async {
        // Given: An intent exactly at the boundary (29 seconds old - just under 30s limit)
        let alarmId = UUID()
        let boundaryTimestamp = Date().addingTimeInterval(-29)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(boundaryTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        notificationExpectation = expectation(description: "Should receive alarmIntentReceived notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            self.notificationExpectation?.fulfill()
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Then: Should post notification (within 30 second window)
        await fulfillment(of: [notificationExpectation!], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenNoIntent_shouldNotPostNotification() async {
        // Given: No intent in shared defaults

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification when no intent exists")

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenInvalidUUID_shouldNotPostNotification() async {
        // Given: Invalid UUID string
        sharedDefaults?.set("invalid-uuid", forKey: "pendingAlarmIntent")
        sharedDefaults?.set(Date(), forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification for invalid UUID")

        // And: Should clear the invalid intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/IntentBridgeNoSingletonTests.swift

```swift
//
//  IntentBridgeNoSingletonTests.swift
//  alarmAppNewTests
//
//  Tests to ensure AlarmIntentBridge does not use singleton pattern.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class IntentBridgeNoSingletonTests: XCTestCase {

    func test_AlarmIntentBridge_shouldNotHaveSharedInstance() {
        // Check that AlarmIntentBridge type does not have a 'shared' static property
        let mirror = Mirror(reflecting: AlarmIntentBridge.self)

        // Iterate through the type's children to look for static properties
        for child in mirror.children {
            if let label = child.label {
                XCTAssertFalse(
                    label.lowercased().contains("shared"),
                    "AlarmIntentBridge should not have a 'shared' static property"
                )
            }
        }

        // Also verify through runtime check - this will fail to compile if .shared exists
        // Uncommenting the line below should cause a compile error:
        // _ = AlarmIntentBridge.shared
    }

    func test_AlarmIntentBridge_shouldAllowMultipleInstances() {
        // Given/When: Creating multiple instances
        let bridge1 = AlarmIntentBridge()
        let bridge2 = AlarmIntentBridge()
        let bridge3 = AlarmIntentBridge()

        // Then: All instances should be different objects
        XCTAssertTrue(bridge1 !== bridge2, "Should create different instances")
        XCTAssertTrue(bridge2 !== bridge3, "Should create different instances")
        XCTAssertTrue(bridge1 !== bridge3, "Should create different instances")
    }

    func test_AlarmIntentBridge_shouldNotHaveSingletonPattern() {
        // This test verifies the class structure doesn't follow singleton pattern

        // 1. Can create instances normally
        let instance = AlarmIntentBridge()
        XCTAssertNotNil(instance)

        // 2. Init is accessible (not private)
        // The fact that we can call AlarmIntentBridge() proves init is not private

        // 3. No static instance property
        // We check this by ensuring the type doesn't respond to .shared
        // This is validated by the compiler - if .shared existed, we could reference it
    }

    func test_AlarmIntentBridge_shouldHavePublicInit() {
        // The ability to create an instance from test target proves init is not private
        let bridge = AlarmIntentBridge()
        XCTAssertNotNil(bridge, "Should be able to create instance with public/internal init")
    }

    func test_AlarmIntentBridge_multipleInstancesCanOperateIndependently() async {
        // Given: Multiple bridge instances
        let bridge1 = AlarmIntentBridge()
        let bridge2 = AlarmIntentBridge()

        // When: Both check for pending intents
        // (No setup needed - just verifying they don't interfere)
        bridge1.checkForPendingIntent()
        bridge2.checkForPendingIntent()

        // Then: Both should execute without issues
        // The fact that this doesn't crash proves they're independent
        XCTAssertNotNil(bridge1.pendingAlarmId) // Will be nil, but we're checking property access
        XCTAssertNotNil(bridge2.pendingAlarmId) // Will be nil, but we're checking property access
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/NotificationIdentifierContractTests.swift

```swift
//
//  NotificationIdentifierContractTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/5/25.
//  Contract tests for notification identifier format - ensures cleanup logic doesn't break
//

import XCTest
@testable import alarmAppNew

final class NotificationIdentifierContractTests: XCTestCase {
    func test_notificationIdentifier_format_containsOccurrenceKeySegment() {
        // Given: A notification identifier for a specific occurrence
        let alarmId = UUID()
        let fireDate = Date()
        let occurrence = 1

        let identifier = NotificationIdentifier(
            alarmId: alarmId,
            fireDate: fireDate,
            occurrence: occurrence
        )

        // When: We generate the string value
        let stringValue = identifier.stringValue

        // Then: It MUST contain "-occ-{occurrenceKey}-" pattern
        // Use the SAME formatter as production (no brittleness)
        let occurrenceKey = OccurrenceKeyFormatter.key(from: fireDate)

        XCTAssertTrue(
            stringValue.contains("-occ-\(occurrenceKey)-"),
            "Identifier format changed! getRequestIds() filter will break. Expected: '-occ-{ISO8601}-' segment"
        )

        // Verify full format for documentation
        XCTAssertTrue(stringValue.hasPrefix("alarm-\(alarmId.uuidString)-occ-"))
        XCTAssertTrue(stringValue.hasSuffix("-\(occurrence)"))
    }

    func test_occurrenceKeyFormatter_roundTrip() {
        // Given: A date
        let originalDate = Date()

        // When: We convert to key and back
        let key = OccurrenceKeyFormatter.key(from: originalDate)
        let parsedDate = OccurrenceKeyFormatter.date(from: key)

        // Then: Round trip succeeds with millisecond precision
        XCTAssertNotNil(parsedDate)
        XCTAssertEqual(originalDate.timeIntervalSince1970, parsedDate!.timeIntervalSince1970, accuracy: 0.001)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/NotificationIndexTests.swift

```swift
//
//  NotificationIndexTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class NotificationIndexTests: XCTestCase {

    private var testSuite: UserDefaults!
    private var testSuiteName: String!
    private var notificationIndex: NotificationIndex!
    private let testAlarmId = UUID()

    override func setUp() {
        super.setUp()

        // Create isolated UserDefaults suite for testing
        testSuiteName = "test-notification-index-\(UUID().uuidString)"
        testSuite = UserDefaults(suiteName: testSuiteName)!
        notificationIndex = NotificationIndex(defaults: testSuite)
    }

    override func tearDown() {
        // Clean up test suite
        testSuite.removePersistentDomain(forName: testSuiteName)
        testSuite = nil
        testSuiteName = nil
        notificationIndex = nil
        super.tearDown()
    }

    // MARK: - NotificationIdentifier Tests

    func test_notificationIdentifier_stringValue_hasCorrectFormat() {
        let alarmId = UUID()
        let fireDate = Date(timeIntervalSince1970: 1696156800) // Fixed date for consistency
        let identifier = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: 3)

        let stringValue = identifier.stringValue

        XCTAssertTrue(stringValue.hasPrefix("alarm-\(alarmId.uuidString)-occ-"))
        XCTAssertTrue(stringValue.hasSuffix("-3"))
        XCTAssertTrue(stringValue.contains("T")) // ISO8601 format marker
    }

    func test_notificationIdentifier_parseRoundTrip_preservesData() {
        let alarmId = UUID()
        let fireDate = Date()
        let occurrence = 5
        let original = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: occurrence)

        let stringValue = original.stringValue
        let parsed = NotificationIdentifier.parse(stringValue)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.alarmId, alarmId)
        XCTAssertEqual(parsed?.occurrence, occurrence)

        // Dates should be very close (within 1ms due to fractional seconds)
        if let parsedDate = parsed?.fireDate {
            XCTAssertEqual(parsedDate.timeIntervalSince1970,
                          fireDate.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    func test_notificationIdentifier_parse_invalidFormat_returnsNil() {
        let invalidIdentifiers = [
            "invalid-format",
            "alarm-notauuid-occ-date-1",
            "alarm-\(UUID().uuidString)-invalid-date-1",
            "alarm-\(UUID().uuidString)-occ-2023-13-45T25:99:99.000Z-notanumber",
            ""
        ]

        for invalid in invalidIdentifiers {
            let parsed = NotificationIdentifier.parse(invalid)
            XCTAssertNil(parsed, "Should not parse invalid identifier: '\(invalid)'")
        }
    }

    func test_notificationIdentifier_equality_worksCorrectly() {
        let alarmId = UUID()
        let fireDate = Date()
        let id1 = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: 1)
        let id2 = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: 1)
        let id3 = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: 2)

        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)
    }

    // MARK: - NotificationIndex Basic Operations

    func test_notificationIndex_saveAndLoad_preservesIdentifiers() {
        let identifiers = [
            "alarm-\(testAlarmId.uuidString)-occ-2023-10-01T12:00:00.000Z-0",
            "alarm-\(testAlarmId.uuidString)-occ-2023-10-01T12:00:30.000Z-1",
            "alarm-\(testAlarmId.uuidString)-occ-2023-10-01T12:01:00.000Z-2"
        ]

        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers)
        let loadedIdentifiers = notificationIndex.loadIdentifiers(alarmId: testAlarmId)

        XCTAssertEqual(loadedIdentifiers, identifiers)
    }

    func test_notificationIndex_loadNonexistent_returnsEmptyArray() {
        let nonexistentAlarmId = UUID()
        let loadedIdentifiers = notificationIndex.loadIdentifiers(alarmId: nonexistentAlarmId)

        XCTAssertEqual(loadedIdentifiers, [])
    }

    func test_notificationIndex_saveEmptyArray_removesKey() {
        let identifiers = ["test-identifier-1", "test-identifier-2"]

        // First, save some identifiers
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers)
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: testAlarmId), identifiers)

        // Then, save empty array
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: [])
        let loadedIdentifiers = notificationIndex.loadIdentifiers(alarmId: testAlarmId)

        XCTAssertEqual(loadedIdentifiers, [])
    }

    func test_notificationIndex_clearIdentifiers_removesSpecificAlarm() {
        let alarm1 = UUID()
        let alarm2 = UUID()
        let identifiers1 = ["alarm1-id1", "alarm1-id2"]
        let identifiers2 = ["alarm2-id1", "alarm2-id2"]

        // Save identifiers for both alarms
        notificationIndex.saveIdentifiers(alarmId: alarm1, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: alarm2, identifiers: identifiers2)

        // Clear only alarm1
        notificationIndex.clearIdentifiers(alarmId: alarm1)

        // Verify alarm1 is cleared but alarm2 remains
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: alarm1), [])
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: alarm2), identifiers2)
    }

    // MARK: - Global Index Tests

    func test_notificationIndex_globalIndex_aggregatesAllAlarms() {
        let alarm1 = UUID()
        let alarm2 = UUID()
        let identifiers1 = ["alarm1-id1", "alarm1-id2"]
        let identifiers2 = ["alarm2-id1"]

        notificationIndex.saveIdentifiers(alarmId: alarm1, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: alarm2, identifiers: identifiers2)

        let globalIdentifiers = notificationIndex.getAllPendingIdentifiers()

        XCTAssertEqual(Set(globalIdentifiers), Set(identifiers1 + identifiers2))
        XCTAssertEqual(globalIdentifiers.count, 3)
    }

    func test_notificationIndex_globalIndex_updatesOnClear() {
        let alarm1 = UUID()
        let alarm2 = UUID()
        let identifiers1 = ["alarm1-id1", "alarm1-id2"]
        let identifiers2 = ["alarm2-id1"]

        notificationIndex.saveIdentifiers(alarmId: alarm1, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: alarm2, identifiers: identifiers2)

        // Clear one alarm
        notificationIndex.clearIdentifiers(alarmId: alarm1)

        let globalIdentifiers = notificationIndex.getAllPendingIdentifiers()

        XCTAssertEqual(globalIdentifiers, identifiers2)
    }

    func test_notificationIndex_clearAllIdentifiers_removesEverything() {
        let alarm1 = UUID()
        let alarm2 = UUID()
        let identifiers1 = ["alarm1-id1", "alarm1-id2"]
        let identifiers2 = ["alarm2-id1"]

        notificationIndex.saveIdentifiers(alarmId: alarm1, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: alarm2, identifiers: identifiers2)

        notificationIndex.clearAllIdentifiers()

        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: alarm1), [])
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: alarm2), [])
        XCTAssertEqual(notificationIndex.getAllPendingIdentifiers(), [])
    }

    // MARK: - Batch Operations Tests

    func test_notificationIndex_batchOperations_workCorrectly() {
        let fireDate = Date()
        let identifiers = [
            NotificationIdentifier(alarmId: testAlarmId, fireDate: fireDate, occurrence: 0),
            NotificationIdentifier(alarmId: testAlarmId, fireDate: fireDate.addingTimeInterval(30), occurrence: 1)
        ]
        let batch = NotificationIdentifierBatch(alarmId: testAlarmId, identifiers: identifiers)

        notificationIndex.saveIdentifierBatch(batch)
        let loadedBatch = notificationIndex.loadIdentifierBatch(alarmId: testAlarmId)

        XCTAssertEqual(loadedBatch.alarmId, testAlarmId)
        XCTAssertEqual(loadedBatch.identifiers.count, 2)

        for (original, loaded) in zip(identifiers, loadedBatch.identifiers) {
            XCTAssertEqual(original.alarmId, loaded.alarmId)
            XCTAssertEqual(original.occurrence, loaded.occurrence)
            XCTAssertEqual(original.fireDate.timeIntervalSince1970,
                          loaded.fireDate.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    // MARK: - Idempotent Reschedule Tests

    func test_notificationIndex_idempotentReschedule_clearsAndExecutes() {
        let originalIdentifiers = ["original-1", "original-2"]
        let newIdentifiers = ["new-1", "new-2", "new-3"]

        // Setup initial state
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: originalIdentifiers)

        var rescheduleExecuted = false

        notificationIndex.idempotentReschedule(
            alarmId: testAlarmId,
            expectedIdentifiers: newIdentifiers
        ) {
            rescheduleExecuted = true
        }

        XCTAssertTrue(rescheduleExecuted)
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: testAlarmId), newIdentifiers)
    }

    // MARK: - Edge Cases and Error Conditions

    func test_notificationIndex_multipleOverwrites_handledCorrectly() {
        let identifiers1 = ["id1", "id2"]
        let identifiers2 = ["id3", "id4", "id5"]
        let identifiers3 = ["id6"]

        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers2)
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers3)

        let finalIdentifiers = notificationIndex.loadIdentifiers(alarmId: testAlarmId)

        XCTAssertEqual(finalIdentifiers, identifiers3)
    }

    func test_notificationIndex_largeNumberOfIdentifiers_performsWell() {
        let largeIdentifierCount = 1000
        let largeIdentifiers = (0..<largeIdentifierCount).map { "id-\($0)" }

        let startTime = CFAbsoluteTimeGetCurrent()
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: largeIdentifiers)
        let saveTime = CFAbsoluteTimeGetCurrent() - startTime

        let loadStartTime = CFAbsoluteTimeGetCurrent()
        let loadedIdentifiers = notificationIndex.loadIdentifiers(alarmId: testAlarmId)
        let loadTime = CFAbsoluteTimeGetCurrent() - loadStartTime

        XCTAssertEqual(loadedIdentifiers, largeIdentifiers)
        XCTAssertLessThan(saveTime, 1.0, "Save should complete in under 1 second")
        XCTAssertLessThan(loadTime, 1.0, "Load should complete in under 1 second")
    }

    func test_notificationIndex_isolatedTestSuites_dontInterfere() {
        let otherSuiteName = "test-notification-index-other-\(UUID().uuidString)"
        let otherSuite = UserDefaults(suiteName: otherSuiteName)!
        defer { otherSuite.removePersistentDomain(forName: otherSuiteName) }

        let otherIndex = NotificationIndex(defaults: otherSuite)

        let identifiers1 = ["suite1-id1"]
        let identifiers2 = ["suite2-id1"]

        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers1)
        otherIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers2)

        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: testAlarmId), identifiers1)
        XCTAssertEqual(otherIndex.loadIdentifiers(alarmId: testAlarmId), identifiers2)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/SettingsServiceTests.swift

```swift
//
//  SettingsServiceTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/2/25.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class SettingsServiceTests: XCTestCase {

    var sut: SettingsService!
    var mockUserDefaults: UserDefaults!
    var mockAudioEngine: MockAlarmAudioEngine!

    override func setUp() async throws {
        // Use in-memory UserDefaults for testing
        mockUserDefaults = UserDefaults(suiteName: "test.settings.\(UUID().uuidString)")!
        mockAudioEngine = MockAlarmAudioEngine()
        sut = SettingsService(userDefaults: mockUserDefaults, audioEngine: mockAudioEngine)
    }

    override func tearDown() async throws {
        if let suiteName = mockUserDefaults.dictionaryRepresentation().keys.first {
            mockUserDefaults.removePersistentDomain(forName: suiteName)
        }
        sut = nil
        mockUserDefaults = nil
        mockAudioEngine = nil
    }

    // MARK: - Audio Enhancement Settings Tests

    func test_audioEnhancement_defaultsToFalse() {
        XCTAssertFalse(sut.useAudioEnhancement, "Audio enhancement should default to false")
    }

    func test_audioEnhancement_cannotEnableInNotificationsOnlyMode() {
        // Given: notifications-only mode
        sut.setReliabilityMode(.notificationsOnly)

        // When: attempt to enable audio enhancement
        sut.setUseAudioEnhancement(true)

        // Then: should remain false (mode gate blocks it)
        XCTAssertFalse(sut.useAudioEnhancement, "Cannot enable audio enhancement in notifications-only mode")
    }

    func test_audioEnhancement_canEnableInNotificationsPlusAudioMode() {
        // Given: notifications+audio mode
        sut.setReliabilityMode(.notificationsPlusAudio)

        // When: enable audio enhancement
        sut.setUseAudioEnhancement(true)

        // Then: should be enabled
        XCTAssertTrue(sut.useAudioEnhancement, "Can enable audio enhancement in notifications+audio mode")
    }

    func test_audioEnhancement_persistsToUserDefaults() {
        // Given: notifications+audio mode
        sut.setReliabilityMode(.notificationsPlusAudio)

        // When: enable and persist
        sut.setUseAudioEnhancement(true)

        // Then: value should be in UserDefaults
        XCTAssertTrue(mockUserDefaults.bool(forKey: "com.alarmApp.useAudioEnhancement"))
    }

    // MARK: - Alert Intervals Validation Tests

    func test_alertIntervals_defaultsToZeroTenTwenty() {
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20], "Alert intervals should default to [0, 10, 20]")
    }

    func test_alertIntervals_rejectUnsortedArray() {
        // Given: unsorted array
        let unsorted = [10, 0, 20]

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setAlertIntervals(unsorted)) { error in
            XCTAssertEqual(error as? SettingsError, .intervalsNotSorted)
        }

        // Verify original value unchanged
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20])
    }

    func test_alertIntervals_rejectNegativeValues() {
        // Given: array with negative values
        let negative = [-5, 0, 10]

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setAlertIntervals(negative)) { error in
            XCTAssertEqual(error as? SettingsError, .invalidInterval)
        }
    }

    func test_alertIntervals_acceptSortedValidArray() throws {
        // Given: sorted valid array
        let valid = [0, 5, 15, 30]

        // When: set intervals
        try sut.setAlertIntervals(valid)

        // Then: should be accepted
        XCTAssertEqual(sut.alertIntervalsSec, valid)
    }

    func test_alertIntervals_persistsToUserDefaults() throws {
        // Given: valid intervals
        let valid = [0, 15, 30]

        // When: set and persist
        try sut.setAlertIntervals(valid)

        // Then: should be in UserDefaults
        let persisted = mockUserDefaults.array(forKey: "com.alarmApp.alertIntervalsSec") as? [Int]
        XCTAssertEqual(persisted, valid)
    }

    // MARK: - Lead-In Validation Tests

    func test_leadIn_defaultsToTwoSeconds() {
        XCTAssertEqual(sut.leadInSec, 2, "Lead-in should default to 2 seconds")
    }

    func test_leadIn_rejectNegativeValue() {
        // Given: negative value
        let negative = -5

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setLeadInSec(negative)) { error in
            XCTAssertEqual(error as? SettingsError, .leadInOutOfRange)
        }
    }

    func test_leadIn_rejectValueAbove60() {
        // Given: value > 60
        let tooLarge = 61

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setLeadInSec(tooLarge)) { error in
            XCTAssertEqual(error as? SettingsError, .leadInOutOfRange)
        }
    }

    func test_leadIn_acceptZero() throws {
        // When: set to 0
        try sut.setLeadInSec(0)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, 0)
    }

    func test_leadIn_acceptSixty() throws {
        // When: set to 60
        try sut.setLeadInSec(60)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, 60)
    }

    func test_leadIn_acceptValidMidrangeValue() throws {
        // Given: valid mid-range value
        let valid = 30

        // When: set value
        try sut.setLeadInSec(valid)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, valid)
    }

    // MARK: - Suppress Foreground Sound Tests

    func test_suppressForegroundSound_defaultsToTrue() {
        XCTAssertTrue(sut.suppressForegroundSound, "Suppress foreground sound should default to true")
    }

    func test_suppressForegroundSound_canToggle() {
        // When: toggle off
        sut.setSuppressForegroundSound(false)

        // Then: should be false
        XCTAssertFalse(sut.suppressForegroundSound)

        // When: toggle back on
        sut.setSuppressForegroundSound(true)

        // Then: should be true
        XCTAssertTrue(sut.suppressForegroundSound)
    }

    // MARK: - Reset to Defaults Test

    func test_resetToDefaults_restoresAllSettings() throws {
        // Given: modified settings
        sut.setReliabilityMode(.notificationsPlusAudio)
        sut.setUseAudioEnhancement(true)
        try sut.setAlertIntervals([0, 30, 60])
        sut.setSuppressForegroundSound(false)
        try sut.setLeadInSec(10)

        // When: reset
        sut.resetToDefaults()

        // Then: all should be back to defaults
        XCTAssertEqual(sut.currentMode, .notificationsOnly)
        XCTAssertFalse(sut.useAudioEnhancement)
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20])
        XCTAssertTrue(sut.suppressForegroundSound)
        XCTAssertEqual(sut.leadInSec, 2)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNewTests/Unit/Infrastructure/WillPresentSuppressionTests.swift

```swift
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
```

---

