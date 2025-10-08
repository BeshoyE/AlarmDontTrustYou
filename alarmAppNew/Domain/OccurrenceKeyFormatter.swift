//
//  OccurrenceKeyFormatter.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/5/25.
//  Shared formatter for occurrence keys used in notification identifiers and dismissal tracking
//

import Foundation

/// Shared formatter for occurrence keys used in notification identifiers and dismissal tracking
/// Ensures consistency between notification scheduling, cleanup, and testing
public enum OccurrenceKeyFormatter {
    /// Generate occurrence key from fire date
    /// Format: ISO8601 with fractional seconds (e.g., "2025-10-05T14:30:00.000Z")
    public static func key(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Parse occurrence key back to date (for validation/testing)
    public static func date(from key: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: key)
    }
}
