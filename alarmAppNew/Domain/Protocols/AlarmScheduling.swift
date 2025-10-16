//
//  AlarmScheduling.swift
//  alarmAppNew
//
//  Domain-level protocol for alarm scheduling operations.
//  This protocol is AlarmKit-agnostic and defines the contract
//  that both legacy (UNNotification) and modern (AlarmKit) implementations must fulfill.
//

import Foundation

/// Domain-level protocol for alarm scheduling operations.
///
/// This protocol unifies scheduling and ringing control, supporting both
/// legacy notification-based alarms and future AlarmKit-based alarms.
///
/// Important: The `stop` method must only be called after challenge validation
/// has been completed successfully. This is enforced at the Presentation layer
/// using the StopAlarmAllowed use case.
public protocol AlarmScheduling {

    /// Request authorization for alarm notifications if not already granted.
    /// This may show system permission dialogs on first call.
    func requestAuthorizationIfNeeded() async throws

    /// Schedule an alarm and return its external identifier.
    /// - Parameter alarm: The alarm to schedule
    /// - Returns: External identifier (e.g., notification ID or AlarmKit ID)
    /// - Throws: If scheduling fails or authorization is denied
    func schedule(alarm: Alarm) async throws -> String

    /// Cancel a scheduled alarm.
    /// - Parameter alarmId: The UUID of the alarm to cancel
    func cancel(alarmId: UUID) async

    /// Get list of currently pending alarm IDs.
    /// - Returns: Array of UUIDs for alarms that are scheduled to fire
    func pendingAlarmIds() async -> [UUID]

    /// Stop a currently ringing alarm.
    ///
    /// IMPORTANT: This method must only be called after all required
    /// challenges have been validated. The Presentation layer must check
    /// StopAlarmAllowed before invoking this method.
    ///
    /// - Parameters:
    ///   - alarmId: The UUID of the alarm to stop
    ///   - intentAlarmId: Optional UUID from the firing intent (for pre-migration alarms)
    /// - Throws: If the alarm cannot be stopped or doesn't exist
    func stop(alarmId: UUID, intentAlarmId: UUID?) async throws

    /// Transition an alarm to countdown/snooze mode.
    ///
    /// This triggers a countdown with the specified duration, after which
    /// the alarm will ring again. On AlarmKit, this uses native countdown.
    /// On legacy systems, this may reschedule the alarm.
    ///
    /// - Parameters:
    ///   - alarmId: The UUID of the alarm to snooze
    ///   - duration: The snooze duration in seconds
    /// - Throws: If the transition fails or alarm doesn't exist
    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws

    /// Reconcile daemon state with persisted alarms (selective, idempotent).
    ///
    /// Uses daemon as source of truth; only schedules missing enabled alarms
    /// and cancels orphaned daemon entries or disabled alarms. Safe to call
    /// during ringing if skipIfRinging is true.
    ///
    /// This method is idempotent and can be called multiple times safely.
    /// It will not cancel and reschedule alarms that are already correctly
    /// scheduled in the daemon.
    ///
    /// - Parameters:
    ///   - alarms: Persisted domain alarms to reconcile against daemon state
    ///   - skipIfRinging: If true, skip reconciliation when alarm is actively alerting
    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async
}