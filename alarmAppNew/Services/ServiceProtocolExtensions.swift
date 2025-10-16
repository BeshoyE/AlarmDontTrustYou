//
//  ServiceProtocolExtensions.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  Extensions to existing protocols for MVP1 dismissal flow
//

import Foundation
import SwiftUI

// MARK: - AlarmScheduling Extensions

extension AlarmScheduling {
    // Cancel notifications for a specific alarm ID
    func cancel(alarmId: UUID) async {
        // Implementation delegates to existing infrastructure
        // This creates the per-day IDs used by the current scheduling system
        let baseID = alarmId.uuidString
        
        // For repeat alarms, we need to cancel all weekday variations
        // The current system uses: "alarmId-weekday-X" format
        var idsToCancel = [baseID]
        
        // Add weekday variations (1-7 for Sunday-Saturday)
        for weekday in 1...7 {
            idsToCancel.append("\(baseID)-weekday-\(weekday)")
        }
        
        // Use the underlying notification center to cancel
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToCancel)
    }
}

// MARK: - Error Types

struct AlarmNotFoundError: Error {}

// MARK: - PersistenceStore Extensions

extension PersistenceStore {
    // Convenience method to find alarm by ID
    func alarm(with id: UUID) throws -> Alarm {
        let alarms = try loadAlarms()
        guard let alarm = alarms.first(where: { $0.id == id }) else {
            throw AlarmNotFoundError()
        }
        return alarm
    }
}

// MARK: - Test Clock

struct TestClock: Clock {
    private var currentTime: Date
    
    init(time: Date = Date()) {
        self.currentTime = time
    }
    
    func now() -> Date {
        currentTime
    }
    
    mutating func advance(by interval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(interval)
    }
    
    mutating func set(to time: Date) {
        currentTime = time
    }
}
