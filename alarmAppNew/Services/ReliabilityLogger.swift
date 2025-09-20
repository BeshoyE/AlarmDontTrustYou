//
//  ReliabilityLogger.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/7/25.
//  Local reliability logging for MVP1 critical events
//

import Foundation

// MARK: - Reliability Events
enum ReliabilityEvent: String, Codable {
    case scheduled = "scheduled"
    case fired = "fired"
    case dismissSuccessQR = "dismiss_success_qr"
    case dismissFailQR = "dismiss_fail_qr"
    case notificationsStatusChanged = "notifications_status_changed"
    case cameraPermissionChanged = "camera_permission_changed"
    case alarmRunCreated = "alarm_run_created"
    case alarmRunCompleted = "alarm_run_completed"
}

// MARK: - Log Entry
struct ReliabilityLogEntry: Codable {
    let id: UUID
    let timestamp: Date
    let event: ReliabilityEvent
    let alarmId: UUID?
    let details: [String: String]
    
    init(event: ReliabilityEvent, alarmId: UUID? = nil, details: [String: String] = [:]) {
        self.id = UUID()
        self.timestamp = Date()
        self.event = event
        self.alarmId = alarmId
        self.details = details
    }
}

// MARK: - Reliability Logger Protocol
protocol ReliabilityLogging {
    func log(_ event: ReliabilityEvent, alarmId: UUID?, details: [String: String])
    func exportLogs() -> String
    func clearLogs()
    func getRecentLogs(limit: Int) -> [ReliabilityLogEntry]
}

// MARK: - Local File Reliability Logger
class LocalReliabilityLogger: ReliabilityLogging {
    private let fileManager = FileManager.default
    private let logFileName = "reliability_log.json"
    private let queue = DispatchQueue(label: "reliability-logger", qos: .utility)

    // State management
    private var didActivate = false
    private var cachedRecentLogs: [ReliabilityLogEntry] = []
    private var isCacheValid = false

    private var logFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(logFileName)
    }

    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Explicit activation to ensure directory exists with proper file protection
    func activate() {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.sync {
            guard !didActivate else { return }

            do {
                try ensureDirectoryExistsInternal()
                didActivate = true
                print("ReliabilityLogger: Activated with directory and file protection")
            } catch {
                print("ReliabilityLogger: Activation failed: \(error)")
            }
        }
    }

    func log(_ event: ReliabilityEvent, alarmId: UUID? = nil, details: [String: String] = [:]) {
        dispatchPrecondition(condition: .notOnQueue(queue))

        let entry = ReliabilityLogEntry(event: event, alarmId: alarmId, details: details)

        // Fire-and-forget write with cache invalidation
        queue.async { [weak self] in
            guard let self = self else { return }
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            self.appendLogEntryInternal(entry)

            // Invalidate cache so UI gets fresh data
            self.isCacheValid = false
        }

        // Also print to console for debugging (immediate, not queued)
        print("ReliabilityLog: \(event.rawValue) - \(alarmId?.uuidString.prefix(8) ?? "N/A") - \(details)")
    }

    func exportLogs() -> String {
        dispatchPrecondition(condition: .notOnQueue(queue))

        return queue.sync {
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            do {
                let logs = try loadLogsInternal()
                let jsonData = try jsonEncoder.encode(logs)
                return String(data: jsonData, encoding: .utf8) ?? "Failed to encode logs"
            } catch {
                print("ReliabilityLogger: Export failed: \(error)")
                return "Failed to export logs: \(error.localizedDescription)"
            }
        }
    }

    func clearLogs() {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.async { [weak self] in
            guard let self = self else { return }
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            do {
                if self.fileManager.fileExists(atPath: self.logFileURL.path) {
                    try self.fileManager.removeItem(at: self.logFileURL)
                }
                // Clear cache after successful clear
                self.cachedRecentLogs = []
                self.isCacheValid = true
            } catch {
                print("Failed to clear reliability logs: \(error)")
            }
        }
    }

    func getRecentLogs(limit: Int = 100) -> [ReliabilityLogEntry] {
        dispatchPrecondition(condition: .notOnQueue(queue))

        return queue.sync {
            // Fast path: return cached data if valid
            if isCacheValid && cachedRecentLogs.count >= limit {
                return Array(cachedRecentLogs.suffix(limit))
            }

            // Slow path: load from disk and update cache
            do {
                let logs = try loadLogsInternal()
                cachedRecentLogs = logs
                isCacheValid = true
                return Array(logs.suffix(limit))
            } catch {
                print("Failed to load recent logs: \(error)")
                return []
            }
        }
    }

    // MARK: - Private Methods

    /// Ensure parent directory exists and has proper file protection for lock screen access
    /// INTERNAL: Call only from within queue context to avoid re-entrancy
    private func ensureDirectoryExistsInternal() throws {
        guard !didActivate else { return }

        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        if !fileManager.fileExists(atPath: documentsPath.path) {
            try fileManager.createDirectory(at: documentsPath, withIntermediateDirectories: true, attributes: [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ])
            print("ReliabilityLogger: Created documents directory with file protection")
        }
    }

    /// INTERNAL: Load logs from disk - call only from within queue context
    private func loadLogsInternal() throws -> [ReliabilityLogEntry] {
        guard fileManager.fileExists(atPath: logFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: logFileURL)
        return try jsonDecoder.decode([ReliabilityLogEntry].self, from: data)
    }

    /// INTERNAL: Append log entry - call only from within queue context
    private func appendLogEntryInternal(_ entry: ReliabilityLogEntry) {
        do {
            // Ensure directory exists with proper file protection (if not already done)
            if !didActivate {
                try ensureDirectoryExistsInternal()
            }

            var logs: [ReliabilityLogEntry] = []

            // Safely load existing logs
            do {
                logs = try loadLogsInternal()
            } catch {
                print("ReliabilityLogger: Could not load existing logs, starting fresh: \(error)")
                // Clear corrupted file and start fresh
                try? fileManager.removeItem(at: logFileURL)
                logs = []
            }

            logs.append(entry)

            // Keep only last 1000 entries to prevent excessive file growth
            if logs.count > 1000 {
                logs = Array(logs.suffix(1000))
            }

            // Use atomic write to prevent corruption with consistent encoding
            let jsonData = try jsonEncoder.encode(logs)

            // Write to temporary file first, then move to final location (atomic)
            let tempURL = logFileURL.appendingPathExtension("tmp")

            // Write with proper file protection for lock screen access
            try jsonData.write(to: tempURL, options: [.atomic])

            // Set file protection on temp file before moving
            try fileManager.setAttributes([
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ], ofItemAtPath: tempURL.path)

            // Atomic swap using replaceItem
            if fileManager.fileExists(atPath: logFileURL.path) {
                _ = try fileManager.replaceItem(at: logFileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            } else {
                // First time - just move the temp file
                try fileManager.moveItem(at: tempURL, to: logFileURL)
            }

            // Re-apply file protection after replace (attributes don't always carry over)
            try fileManager.setAttributes([
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ], ofItemAtPath: logFileURL.path)

        } catch {
            print("Failed to append reliability log entry: \(error)")

            // Clean up temp file if it exists
            let tempURL = logFileURL.appendingPathExtension("tmp")
            try? fileManager.removeItem(at: tempURL)

            // Last resort: try to clear the corrupted file
            if error.localizedDescription.contains("JSON") || error.localizedDescription.contains("dataCorrupted") {
                print("ReliabilityLogger: Clearing corrupted log file")
                try? fileManager.removeItem(at: logFileURL)
            }
        }
    }
}

// MARK: - Convenience Extensions
extension ReliabilityLogging {
    func logAlarmScheduled(_ alarmId: UUID, details: [String: String] = [:]) {
        log(.scheduled, alarmId: alarmId, details: details)
    }
    
    func logAlarmFired(_ alarmId: UUID, details: [String: String] = [:]) {
        log(.fired, alarmId: alarmId, details: details)
    }
    
    func logDismissSuccess(_ alarmId: UUID, method: String = "qr", details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["method"] = method
        log(.dismissSuccessQR, alarmId: alarmId, details: enrichedDetails)
    }
    
    func logDismissFail(_ alarmId: UUID, reason: String, details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["reason"] = reason
        log(.dismissFailQR, alarmId: alarmId, details: enrichedDetails)
    }
    
    func logPermissionChange(_ permission: String, status: String, details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["permission"] = permission
        enrichedDetails["status"] = status
        log(.notificationsStatusChanged, alarmId: nil, details: enrichedDetails)
    }
}