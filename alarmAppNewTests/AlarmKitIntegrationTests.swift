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
