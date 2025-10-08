//
//  RefreshRequesting.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/7/25.
//  Protocol for requesting notification refresh operations
//

import Foundation

/// Protocol for requesting notification refresh operations
protocol RefreshRequesting {
    func requestRefresh(alarms: [Alarm]) async
}

// RefreshCoordinator already has the exact method signature
// Just declare conformance without implementing anything
extension RefreshCoordinator: RefreshRequesting {}