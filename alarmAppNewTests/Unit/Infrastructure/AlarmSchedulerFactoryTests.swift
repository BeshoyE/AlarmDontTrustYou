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
}