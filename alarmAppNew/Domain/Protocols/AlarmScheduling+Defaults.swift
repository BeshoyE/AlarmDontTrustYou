//
//  AlarmScheduling+Defaults.swift
//  alarmAppNew
//
//  Default implementations for AlarmScheduling protocol methods.
//  These allow legacy implementations to adopt the protocol without
//  immediately implementing all new methods.
//

import Foundation

/// Default implementations for backward compatibility.
///
/// These defaults allow the legacy NotificationService to compile
/// without modification while we transition to the full AlarmScheduling protocol.
public extension AlarmScheduling {

    /// Default no-op implementation for authorization.
    /// Legacy implementations may already handle this differently.
    func requestAuthorizationIfNeeded() async throws {
        // No-op default: Legacy implementations handle auth their own way
    }

    /// Default implementation returns a UUID string for compatibility.
    /// Legacy implementations should override this.
    func schedule(alarm: Alarm) async throws -> String {
        // Default: return alarm ID as external identifier
        // Concrete implementations should override this
        return alarm.id.uuidString
    }

    /// Default no-op implementation for stop.
    /// AlarmKit implementations will override this with actual stop behavior.
    func stop(alarmId: UUID) async throws {
        // No-op default: Legacy systems don't have explicit stop
        // AlarmKit adapter will provide real implementation
    }

    /// Default no-op implementation for countdown transition.
    /// AlarmKit implementations will use native countdown; legacy may reschedule.
    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        // No-op default: Legacy systems handle snooze differently
        // AlarmKit adapter will provide real countdown implementation
    }
}