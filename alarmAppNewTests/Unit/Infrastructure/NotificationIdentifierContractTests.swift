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
