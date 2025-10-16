//
//  AlarmRunStoreError.swift
//  alarmAppNew
//
//  Domain-level error type for AlarmRun persistence operations.
//  Per CLAUDE.md §5.5 error handling strategy and §9 persistence contracts.
//

import Foundation

/// Domain-level errors for AlarmRun persistence operations.
///
/// This enum provides a clean abstraction over infrastructure-specific errors,
/// allowing the Presentation layer to remain decoupled from concrete
/// persistence implementations like AlarmRunStore.
///
/// Per CLAUDE.md §9: All persistence operations must throw typed domain errors.
public enum AlarmRunStoreError: Error, Equatable {
    case saveFailed
    case loadFailed
    case dataCorrupted

    /// Human-readable description for logging and debugging
    public var description: String {
        switch self {
        case .saveFailed:
            return "Failed to save alarm run to persistent storage"
        case .loadFailed:
            return "Failed to load alarm runs from persistent storage"
        case .dataCorrupted:
            return "Alarm run data is corrupted or invalid"
        }
    }
}
