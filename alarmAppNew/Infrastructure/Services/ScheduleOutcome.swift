//
//  ScheduleOutcome.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

public enum UnavailableReason {
    case permissions
    case globalLimit
    case invalidConfiguration
    case other(Error)
}

public enum ScheduleOutcome {
    case scheduled(count: Int)
    case trimmed(original: Int, scheduled: Int)
    case unavailable(reason: UnavailableReason)

    public var isSuccess: Bool {
        switch self {
        case .scheduled, .trimmed:
            return true
        case .unavailable:
            return false
        }
    }

    public var scheduledCount: Int {
        switch self {
        case .scheduled(let count):
            return count
        case .trimmed(_, let scheduled):
            return scheduled
        case .unavailable:
            return 0
        }
    }
}

extension ScheduleOutcome: Equatable {
    public static func == (lhs: ScheduleOutcome, rhs: ScheduleOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.scheduled(let lhsCount), .scheduled(let rhsCount)):
            return lhsCount == rhsCount
        case (.trimmed(let lhsOriginal, let lhsScheduled), .trimmed(let rhsOriginal, let rhsScheduled)):
            return lhsOriginal == rhsOriginal && lhsScheduled == rhsScheduled
        case (.unavailable(let lhsReason), .unavailable(let rhsReason)):
            // Simple comparison - could be enhanced for specific error types
            return String(describing: lhsReason) == String(describing: rhsReason)
        default:
            return false
        }
    }
}