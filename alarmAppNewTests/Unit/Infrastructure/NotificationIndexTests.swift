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
}