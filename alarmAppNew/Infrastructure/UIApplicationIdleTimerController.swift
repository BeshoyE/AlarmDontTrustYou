//
//  UIApplicationIdleTimerController.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/10/25.
//  Concrete implementation of IdleTimerControlling using UIApplication
//

import UIKit

/// Concrete implementation that controls the screen idle timer via UIApplication.
/// This isolates UIKit dependencies to the Infrastructure layer.
@MainActor
final class UIApplicationIdleTimerController: IdleTimerControlling {
    func setIdleTimer(disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}
