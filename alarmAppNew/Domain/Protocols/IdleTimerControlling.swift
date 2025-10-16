//
//  IdleTimerControlling.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/10/25.
//  Protocol for controlling screen idle timer state
//

import Foundation

/// Protocol for controlling the device screen idle timer.
/// This abstraction allows ViewModels to keep the screen awake without directly depending on UIKit.
public protocol IdleTimerControlling {
    /// Sets whether the idle timer should be disabled.
    /// - Parameter disabled: If true, prevents the screen from sleeping; if false, allows normal sleep behavior
    func setIdleTimer(disabled: Bool)
}
