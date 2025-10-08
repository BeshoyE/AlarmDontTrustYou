//
//  NotificationIdentifiers.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

public struct NotificationIdentifier {
    public let alarmId: UUID
    public let fireDate: Date
    public let occurrence: Int

    public init(alarmId: UUID, fireDate: Date, occurrence: Int) {
        self.alarmId = alarmId
        self.fireDate = fireDate
        self.occurrence = occurrence
    }

    public var stringValue: String {
        let dateString = OccurrenceKeyFormatter.key(from: fireDate)
        return "alarm-\(alarmId.uuidString)-occ-\(dateString)-\(occurrence)"
    }

    public static func parse(_ identifier: String) -> NotificationIdentifier? {
        // Expected format: "alarm-{uuid}-occ-{ISO8601}-{occurrence}"
        guard identifier.hasPrefix("alarm-") else { return nil }

        // Remove "alarm-" prefix
        let withoutPrefix = String(identifier.dropFirst(6))

        // Find the UUID part (36 characters + hyphen)
        guard withoutPrefix.count > 37 else { return nil }
        let uuidString = String(withoutPrefix.prefix(36))
        guard let alarmId = UUID(uuidString: uuidString) else { return nil }

        // Remove UUID and the following hyphen
        let remainder = String(withoutPrefix.dropFirst(37))

        // Should start with "occ-"
        guard remainder.hasPrefix("occ-") else { return nil }

        // Remove "occ-" prefix
        let dateAndOccurrence = String(remainder.dropFirst(4))

        // Find the last hyphen which separates the occurrence number
        guard let lastHyphenIndex = dateAndOccurrence.lastIndex(of: "-") else { return nil }

        // Split into date and occurrence
        let dateString = String(dateAndOccurrence[..<lastHyphenIndex])
        let occurrenceString = String(dateAndOccurrence[dateAndOccurrence.index(after: lastHyphenIndex)...])

        // Parse occurrence
        guard let occurrence = Int(occurrenceString) else { return nil }

        // Parse date
        guard let fireDate = OccurrenceKeyFormatter.date(from: dateString) else { return nil }

        return NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: occurrence)
    }
}

extension NotificationIdentifier: Codable, Equatable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }
}

public struct NotificationIdentifierBatch {
    public let alarmId: UUID
    public let identifiers: [NotificationIdentifier]

    public init(alarmId: UUID, identifiers: [NotificationIdentifier]) {
        self.alarmId = alarmId
        self.identifiers = identifiers
    }

    public var stringValues: [String] {
        return identifiers.map(\.stringValue)
    }
}

extension NotificationIdentifierBatch: Codable, Equatable {}