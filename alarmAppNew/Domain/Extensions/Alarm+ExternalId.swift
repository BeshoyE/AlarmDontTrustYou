//
//  Alarm+ExternalId.swift
//  alarmAppNew
//
//  Extension for managing AlarmKit external identifiers.
//

import Foundation

public extension Alarm {
    /// Returns a copy of the alarm with the specified external ID
    func withExternalId(_ id: String?) -> Alarm {
        var copy = self
        copy.externalAlarmId = id
        return copy
    }

    /// Checks if this alarm has an external ID assigned
    var hasExternalId: Bool {
        externalAlarmId != nil
    }
}