//
//  ClockExtensions.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

// Note: Clock protocol is defined in DismissalFlowViewModel.swift
// This file extends it with test utilities

public struct MockClock: Clock {
    public var fixedNow: Date

    public init(fixedNow: Date = Date()) {
        self.fixedNow = fixedNow
    }

    public func now() -> Date {
        return fixedNow
    }

    public mutating func advance(by timeInterval: TimeInterval) {
        fixedNow = fixedNow.addingTimeInterval(timeInterval)
    }
}