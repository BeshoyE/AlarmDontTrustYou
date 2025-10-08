//
//  AlarmFactory.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public protocol AlarmFactory {
    /// Creates a new alarm with sensible defaults, including a valid soundId from the sound catalog
    func makeNewAlarm() -> Alarm
}