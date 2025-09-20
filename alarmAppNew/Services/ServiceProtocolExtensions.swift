//
//  ServiceProtocolExtensions.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  Extensions to existing protocols for MVP1 dismissal flow
//

import Foundation
import SwiftUI

// MARK: - NotificationScheduling Extensions

extension NotificationScheduling {
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

// MARK: - AlarmStorage Extensions

extension AlarmStorage {
    // Convenience method to find alarm by ID
    func alarm(with id: UUID) throws -> Alarm {
        let alarms = try loadAlarms()
        guard let alarm = alarms.first(where: { $0.id == id }) else {
            throw AlarmStorageError.alarmNotFound
        }
        return alarm
    }
    
    // Method to append alarm run outcomes
    func appendRun(_ run: AlarmRun) throws {
        // Implementation will store runs alongside alarms using UserDefaults pattern
        let encoder = JSONEncoder()
        
        // Load existing runs
        var existingRuns: [AlarmRun] = []
        if let data = UserDefaults.standard.data(forKey: "alarm_runs"),
           let decoded = try? JSONDecoder().decode([AlarmRun].self, from: data) {
            existingRuns = decoded
        }
        
        // Append new run
        existingRuns.append(run)
        
        // Save back to UserDefaults
        do {
            let encoded = try encoder.encode(existingRuns)
            UserDefaults.standard.set(encoded, forKey: "alarm_runs")
        } catch {
            throw AlarmStorageError.saveFailed
        }
    }
    
    // Method to load alarm runs (for analytics/debugging)
    func loadRuns() throws -> [AlarmRun] {
        guard let data = UserDefaults.standard.data(forKey: "alarm_runs"),
              let runs = try? JSONDecoder().decode([AlarmRun].self, from: data) else {
            return [] // No runs stored yet
        }
        return runs
    }
    
    // Method to load runs for a specific alarm
    func runs(for alarmId: UUID) throws -> [AlarmRun] {
        let allRuns = try loadRuns()
        return allRuns.filter { $0.alarmId == alarmId }
    }
    
    // Method to clean up incomplete runs on app restart
    func cleanupIncompleteRuns() throws {
        var allRuns = try loadRuns()
        let now = Date()
        var hasChanges = false
        
        // Mark incomplete runs older than 1 hour as failed
        for i in 0..<allRuns.count {
            let run = allRuns[i]
            
            // If run is incomplete (no dismissedAt) and older than 1 hour, mark as failed
            if run.dismissedAt == nil && 
               run.outcome == .failed && // Default state
               now.timeIntervalSince(run.firedAt) > 3600 { // 1 hour
                
                allRuns[i].outcome = .failed
                hasChanges = true
                print("Marked stale AlarmRun as failed: \(run.id)")
            }
        }
        
        // Save changes if any
        if hasChanges {
            let encoded = try JSONEncoder().encode(allRuns)
            UserDefaults.standard.set(encoded, forKey: "alarm_runs")
        }
    }
}

// MARK: - Error Types

enum AlarmStorageError: Error, LocalizedError {
    case alarmNotFound
    case saveFailed
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .alarmNotFound:
            return "Alarm not found"
        case .saveFailed:
            return "Failed to save data"
        case .loadFailed:
            return "Failed to load data"
        }
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
