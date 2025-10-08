//
//  AlarmFactoryTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/24/25.
//

import XCTest
@testable import alarmAppNew

final class AlarmFactoryTests: XCTestCase {

    private var mockCatalog: MockSoundCatalog!
    private var factory: DefaultAlarmFactory!

    override func setUp() {
        super.setUp()
        mockCatalog = MockSoundCatalog()
        factory = DefaultAlarmFactory(catalog: mockCatalog)
    }

    override func tearDown() {
        factory = nil
        mockCatalog = nil
        super.tearDown()
    }

    // MARK: - Basic Creation Tests

    func testAlarmFactory_makeNewAlarm_setsCorrectDefaults() {
        // Given: A factory with mock catalog
        // When: We create a new alarm
        let alarm = factory.makeNewAlarm()

        // Then: It should have sensible defaults
        XCTAssertNotEqual(alarm.id, UUID()) // Should have a unique ID (not zero UUID)
        XCTAssertEqual(alarm.label, "New Alarm")
        XCTAssertTrue(alarm.repeatDays.isEmpty)
        XCTAssertTrue(alarm.challengeKind.isEmpty)
        XCTAssertNil(alarm.expectedQR)
        XCTAssertNil(alarm.stepThreshold)
        XCTAssertNil(alarm.mathChallenge)
        XCTAssertTrue(alarm.isEnabled)
        XCTAssertEqual(alarm.volume, 0.8)
        XCTAssertNil(alarm.soundName) // Legacy field should be nil
    }

    func testAlarmFactory_makeNewAlarm_usesCatalogDefaultSoundId() {
        // Given: A factory with mock catalog that has a specific default
        mockCatalog.defaultSoundId = "test-default-sound"

        // When: We create a new alarm
        let alarm = factory.makeNewAlarm()

        // Then: It should use the catalog's default sound ID
        XCTAssertEqual(alarm.soundId, "test-default-sound")
    }

    func testAlarmFactory_makeNewAlarm_setsTimeInFuture() {
        // Given: A factory and the current time
        let beforeCreation = Date()

        // When: We create a new alarm
        let alarm = factory.makeNewAlarm()

        // Then: The alarm time should be in the future
        XCTAssertGreaterThan(alarm.time, beforeCreation)
    }

    func testAlarmFactory_makeNewAlarm_createsUniqueAlarms() {
        // Given: A factory
        // When: We create multiple alarms
        let alarm1 = factory.makeNewAlarm()
        let alarm2 = factory.makeNewAlarm()

        // Then: Each alarm should have a unique ID
        XCTAssertNotEqual(alarm1.id, alarm2.id)
    }

    // MARK: - Catalog Integration Tests

    func testAlarmFactory_respectsCatalogChanges() {
        // Given: A factory with an initial catalog
        let initialAlarm = factory.makeNewAlarm()
        XCTAssertEqual(initialAlarm.soundId, mockCatalog.defaultSoundId)

        // When: We change the catalog's default (simulate different catalog)
        let newMockCatalog = MockSoundCatalog()
        newMockCatalog.defaultSoundId = "different-default"
        let newFactory = DefaultAlarmFactory(catalog: newMockCatalog)

        // Then: New alarms should use the new default
        let newAlarm = newFactory.makeNewAlarm()
        XCTAssertEqual(newAlarm.soundId, "different-default")
    }
}

// MARK: - Mock Sound Catalog for Testing

private class MockSoundCatalog: SoundCatalogProviding {
    var defaultSoundId: String = "mock-default"

    var all: [AlarmSound] = [
        AlarmSound(id: "mock-default", name: "Mock Default", fileName: "mock.caf", durationSec: 10),
        AlarmSound(id: "mock-alternative", name: "Mock Alternative", fileName: "alt.caf", durationSec: 15)
    ]

    func info(for id: String) -> AlarmSound? {
        all.first { $0.id == id }
    }
}