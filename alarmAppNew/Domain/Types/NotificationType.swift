//
//  NotificationType.swift
//  alarmAppNew
//
//  Pure Domain type for notification categories.
//  Unified definition to avoid duplication across the codebase.
//

import Foundation

/// Type-safe notification type enumeration
public enum NotificationType: String, CaseIterable, Equatable {
    case main = "main"
    case preAlarm = "pre_alarm"
    case nudge1 = "nudge_1"
    case nudge2 = "nudge_2"
    case nudge3 = "nudge_3"

    /// All nudge notification types
    public static var allNudges: [NotificationType] {
        return [.nudge1, .nudge2, .nudge3]
    }
}