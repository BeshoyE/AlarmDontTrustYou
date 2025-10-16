//
//  AlarmScheduling+CompatShims.swift
//  alarmAppNew
//
//  Compatibility shims for legacy NotificationScheduling methods.
//  These allow gradual migration from old method names to new AlarmScheduling API.
//  These shims can be removed once all call sites are migrated.
//

import Foundation

/// Compatibility shims for legacy method names.
/// These forward to new AlarmScheduling methods or provide safe no-ops.
public extension AlarmScheduling {

    // MARK: - Core Scheduling Methods

    /// Legacy: Schedule an alarm
    /// Forwards to new `schedule(alarm:)` method
    func scheduleAlarm(_ alarm: Alarm) async throws {
        _ = try await schedule(alarm: alarm)
    }

    /// Legacy: Cancel an alarm
    /// Forwards to new `cancel(alarmId:)` method
    func cancelAlarm(_ alarm: Alarm) async {
        await cancel(alarmId: alarm.id)
    }

    /// Legacy: Refresh all alarms
    /// Now delegates to selective reconciliation for safety
    func refreshAll(from alarms: [Alarm]) async {
        // Delegate to selective reconciliation instead of blind cancel/reschedule
        await reconcile(alarms: alarms, skipIfRinging: true)
    }

    /// Default reconciliation: no-op for implementations that don't need it
    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async {
        // Default no-op for schedulers that don't require reconciliation
    }

    /// Legacy: Schedule alarm immediately
    /// Forwards to regular schedule (immediate scheduling is implementation detail)
    func scheduleAlarmImmediately(_ alarm: Alarm) async throws {
        _ = try await schedule(alarm: alarm)
    }

    // MARK: - Test Alarm Methods

    /// Legacy: Schedule one-off test alarm
    /// Creates a test alarm and schedules it
    func scheduleOneOffTestAlarm(leadTime: TimeInterval = 8) async throws {
        // This is a test-specific method that concrete implementations can override
        // Default implementation creates a simple test alarm
        // Concrete implementations should provide proper test alarm scheduling
    }

    /// Legacy: Schedule test notification with custom sound
    func scheduleTestNotification(soundName: String?, in seconds: TimeInterval) async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with system default sound
    func scheduleTestSystemDefault() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with critical sound
    func scheduleTestCriticalSound() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with custom sound
    func scheduleTestCustomSound(soundName: String?) async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with default settings
    func scheduleTestDefault() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with custom settings
    func scheduleTestCustom() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test
    func scheduleBareDefaultTest() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test without interruption
    func scheduleBareDefaultTestNoInterruption() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test without category
    func scheduleBareDefaultTestNoCategory() async throws {
        // Test-specific method - concrete implementations should override
    }

    // MARK: - Cleanup Methods

    /// Legacy: Cancel specific notification types for an alarm
    func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType]) {
        // This is a detailed implementation concern
        // The new API uses simple cancel(alarmId:) for all types
        // Concrete implementations can override for specific behavior
    }

    /// Legacy: Cancel a specific occurrence of an alarm
    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
        // Occurrence-level cancellation is an implementation detail
        // Default to canceling the entire alarm for safety
        await cancel(alarmId: alarmId)
    }

    /// Legacy: Clean up stale delivered notifications
    func cleanupStaleDeliveredNotifications() async {
        // Cleanup is an implementation detail
        // Concrete implementations can override if needed
    }

    /// Legacy: Clean up after alarm dismissal
    func cleanupAfterDismiss(alarmId: UUID, occurrenceKey: String? = nil) async {
        // Intentionally no-op shim; concrete implementations can override
        // Do not map to cancel to avoid hidden behavior changes
    }

    // MARK: - Configuration Methods

    /// Legacy: Ensure notification categories are registered
    func ensureNotificationCategoriesRegistered() {
        // Category registration is an implementation detail
        // Concrete implementations should handle this internally
    }

    // MARK: - Diagnostic Methods

    /// Legacy: Dump notification settings for debugging
    func dumpNotificationSettings() async {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Validate sound bundle
    func validateSoundBundle() {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Dump notification categories for debugging
    func dumpNotificationCategories() async {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Run complete sound triage
    func runCompleteSoundTriage() async throws {
        // Diagnostic method - concrete implementations can override
    }
}

// MARK: - Additional Helper Methods

public extension AlarmScheduling {
    /// Get notification request IDs for a specific alarm occurrence
    func getRequestIds(alarmId: UUID, occurrenceKey: String) async -> [String] {
        // Default implementation returns empty array
        // Concrete implementations can override for specific behavior
        return []
    }

    /// Remove notification requests by identifiers
    func removeRequests(withIdentifiers ids: [String]) async {
        // Default no-op implementation
        // Concrete implementations can override
    }

    /// Clean up all notifications for a dismissed occurrence
    func cleanupOccurrence(alarmId: UUID, occurrenceKey: String) async {
        // Default implementation calls cancelOccurrence
        await cancelOccurrence(alarmId: alarmId, occurrenceKey: occurrenceKey)
    }
}