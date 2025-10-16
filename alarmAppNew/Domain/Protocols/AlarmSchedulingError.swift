//
//  AlarmSchedulingError.swift
//  alarmAppNew
//
//  Domain-level error protocol for alarm scheduling operations.
//  Keeps Presentation layer fully protocol-typed per CLAUDE.md §1.
//

import Foundation

/// Domain-level errors for alarm scheduling operations.
///
/// This enum provides a clean abstraction over infrastructure-specific errors,
/// allowing the Presentation layer to remain decoupled from concrete
/// implementations like AlarmKitScheduler.
public enum AlarmSchedulingError: Error, Equatable {
    case notAuthorized
    case schedulingFailed
    case alarmNotFound
    case invalidConfiguration
    case systemLimitExceeded
    case permissionDenied
    case ambiguousAlarmState
    case alreadyHandledBySystem  // System auto-dismissed alarm when app foregrounded

    /// Human-readable description for logging and debugging
    public var description: String {
        switch self {
        case .notAuthorized:
            return "AlarmKit authorization not granted"
        case .schedulingFailed:
            return "Failed to schedule alarm"
        case .alarmNotFound:
            return "Alarm not found in system"
        case .invalidConfiguration:
            return "Invalid alarm configuration"
        case .systemLimitExceeded:
            return "System alarm limit exceeded"
        case .permissionDenied:
            return "Permission denied"
        case .ambiguousAlarmState:
            return "Multiple alarms alerting - cannot determine which to stop"
        case .alreadyHandledBySystem:
            return "Alarm was already handled by system (auto-dismissed)"
        }
    }
}
