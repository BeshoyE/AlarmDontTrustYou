//
//  Notification+Names.swift
//  alarmAppNew
//
//  Extension for custom notification names used in the app.
//

import Foundation

extension Notification.Name {
    /// Posted when an alarm intent is received from the app group
    static let alarmIntentReceived = Notification.Name("alarmIntentReceived")
}