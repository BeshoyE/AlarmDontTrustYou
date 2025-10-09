//
//  OccurrenceKey.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Pure Swift utility for occurrence key value type and parsing extensions
//

import Foundation

/// Value type representing a unique occurrence of an alarm
/// Used to identify specific instances of repeating alarms
public struct OccurrenceKey: Equatable, Hashable {
    public let date: Date

    public init(date: Date) {
        self.date = date
    }
}

/// Extension to OccurrenceKeyFormatter for parsing notification identifiers
/// Complements the existing key(from:) method in OccurrenceKeyFormatter.swift
extension OccurrenceKeyFormatter {

    // MARK: - Parsing

    /// Parse an occurrence key from a notification identifier
    /// Expected format: "alarm-{uuid}-occ-{ISO8601}-{index}"
    /// Example: "alarm-12345678-1234-1234-1234-123456789012-occ-2025-10-09T00:15:00Z-0"
    public static func parse(fromIdentifier identifier: String) -> OccurrenceKey? {
        guard let date = parseDate(from: identifier) else {
            return nil
        }
        return OccurrenceKey(date: date)
    }

    /// Parse just the date component from an identifier
    /// Returns nil if the identifier doesn't match the expected format
    public static func parseDate(from identifier: String) -> Date? {
        // Split by "-occ-" to isolate the occurrence portion
        let parts = identifier.components(separatedBy: "-occ-")
        guard parts.count >= 2 else {
            return nil
        }

        // The second part contains: "{ISO8601}-{index}"
        // Split by last "-" to remove the index
        let occurrencePart = parts[1]
        let occurrenceComponents = occurrencePart.components(separatedBy: "-")

        // ISO8601 format is "YYYY-MM-DDTHH:MM:SSZ" or "YYYY-MM-DDTHH:MM:SS.sssZ"
        // This contains 2 internal "-" characters (YYYY-MM-DD)
        // So we need at least 3 components: [YYYY, MM, DD...] + potential index at end
        guard occurrenceComponents.count >= 3 else {
            return nil
        }

        // Reconstruct the ISO8601 string by taking all but the last component
        // (the last component is the index number)
        let iso8601String = occurrenceComponents.dropLast().joined(separator: "-")

        // Parse ISO8601 string to Date (use existing method for consistency)
        return date(from: iso8601String)
    }

    /// Parse the alarm ID from an identifier
    /// Expected format: "alarm-{uuid}-occ-{ISO8601}-{index}"
    public static func parseAlarmId(from identifier: String) -> UUID? {
        // Split by "-occ-" to isolate the alarm portion
        let parts = identifier.components(separatedBy: "-occ-")
        guard parts.count >= 2 else {
            return nil
        }

        // The first part is "alarm-{uuid}"
        let alarmPart = parts[0]

        // Remove "alarm-" prefix
        guard alarmPart.hasPrefix("alarm-") else {
            return nil
        }

        let uuidString = String(alarmPart.dropFirst("alarm-".count))
        return UUID(uuidString: uuidString)
    }
}
