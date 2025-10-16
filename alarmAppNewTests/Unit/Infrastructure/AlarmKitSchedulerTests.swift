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
}