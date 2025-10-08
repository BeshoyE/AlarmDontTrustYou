//
//  NotificationIndex.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

// MARK: - Chain Metadata

public struct ChainMeta: Codable {
    public let start: Date          // Actual start time (shifted for minLeadTime)
    public let spacing: TimeInterval
    public let count: Int
    public let createdAt: Date      // When this chain was scheduled

    public init(start: Date, spacing: TimeInterval, count: Int, createdAt: Date) {
        self.start = start
        self.spacing = spacing
        self.count = count
        self.createdAt = createdAt
    }
}

public protocol NotificationIndexProviding {
    func saveIdentifiers(alarmId: UUID, identifiers: [String])
    func loadIdentifiers(alarmId: UUID) -> [String]
    func clearIdentifiers(alarmId: UUID)
    func getAllPendingIdentifiers() -> [String]
    func clearAllIdentifiers()
    func allTrackedAlarmIds() -> [UUID]
    func removeIdentifiers(alarmId: UUID, identifiers: [String])

    // Chain metadata persistence
    func saveChainMeta(alarmId: UUID, meta: ChainMeta)
    func loadChainMeta(alarmId: UUID) -> ChainMeta?
    func clearChainMeta(alarmId: UUID)
}

public final class NotificationIndex: NotificationIndexProviding {
    private let defaults: UserDefaults
    private let keyPrefix = "notification_index"
    private let metaKeyPrefix = "notification_meta"
    private let globalKey = "notification_index_global"
    private let log = OSLog(subsystem: "alarmAppNew", category: "NotificationIndex")

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public Interface

    public func saveIdentifiers(alarmId: UUID, identifiers: [String]) {
        let key = makeKey(for: alarmId)

        os_log("Saving %d identifiers for alarm %@",
               log: log, type: .info, identifiers.count, alarmId.uuidString)

        if identifiers.isEmpty {
            // Remove the key entirely if no identifiers
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(identifiers, forKey: key)
        }

        // Update global index
        updateGlobalIndex()

        #if DEBUG
        // Verify the save in debug builds
        let savedIdentifiers = loadIdentifiers(alarmId: alarmId)
        assert(savedIdentifiers == identifiers, "Identifier save verification failed")
        #endif
    }

    public func loadIdentifiers(alarmId: UUID) -> [String] {
        let key = makeKey(for: alarmId)
        let identifiers = defaults.stringArray(forKey: key) ?? []

        os_log("Loaded %d identifiers for alarm %@",
               log: log, type: .debug, identifiers.count, alarmId.uuidString)

        return identifiers
    }

    public func clearIdentifiers(alarmId: UUID) {
        let key = makeKey(for: alarmId)

        os_log("Clearing identifiers for alarm %@",
               log: log, type: .info, alarmId.uuidString)

        defaults.removeObject(forKey: key)
        updateGlobalIndex()
    }

    public func getAllPendingIdentifiers() -> [String] {
        let globalIdentifiers = defaults.stringArray(forKey: globalKey) ?? []

        os_log("Retrieved %d total pending identifiers",
               log: log, type: .debug, globalIdentifiers.count)

        return globalIdentifiers
    }

    public func clearAllIdentifiers() {
        os_log("Clearing all notification identifiers and metadata", log: log, type: .info)

        // Find all alarm-specific keys (both identifiers and metadata)
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter { $0.hasPrefix(keyPrefix) && $0 != globalKey }
        let metaKeys = allKeys.filter { $0.hasPrefix(metaKeyPrefix) }

        for key in notificationKeys {
            defaults.removeObject(forKey: key)
        }

        for key in metaKeys {
            defaults.removeObject(forKey: key)
        }

        // Clear global index
        defaults.removeObject(forKey: globalKey)

        os_log("Cleared %d identifier keys and %d metadata keys",
               log: log, type: .info, notificationKeys.count, metaKeys.count)
    }

    public func allTrackedAlarmIds() -> [UUID] {
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter {
            $0.hasPrefix("\(keyPrefix)_") && $0 != globalKey
        }

        let alarmIds = notificationKeys.compactMap { key -> UUID? in
            let uuidString = key.replacingOccurrences(of: "\(keyPrefix)_", with: "")
            return UUID(uuidString: uuidString)
        }

        os_log("Found %d tracked alarm IDs", log: log, type: .debug, alarmIds.count)
        return alarmIds
    }

    public func removeIdentifiers(alarmId: UUID, identifiers: [String]) {
        var current = loadIdentifiers(alarmId: alarmId)
        let initialCount = current.count

        current.removeAll { identifiers.contains($0) }

        os_log("Removing %d identifiers from alarm %@ (had: %d, now: %d)",
               log: log, type: .info, initialCount - current.count,
               alarmId.uuidString, initialCount, current.count)

        if current.isEmpty {
            clearIdentifiers(alarmId: alarmId)
        } else {
            saveIdentifiers(alarmId: alarmId, identifiers: current)
        }
    }

    // MARK: - Chain Metadata Persistence

    public func saveChainMeta(alarmId: UUID, meta: ChainMeta) {
        let key = makeMetaKey(for: alarmId)

        do {
            let data = try JSONEncoder().encode(meta)
            defaults.set(data, forKey: key)

            os_log("Saved chain metadata for alarm %@ (start: %@, count: %d)",
                   log: log, type: .info, alarmId.uuidString,
                   meta.start.ISO8601Format(), meta.count)
        } catch {
            os_log("Failed to save chain metadata for alarm %@: %@",
                   log: log, type: .error, alarmId.uuidString, error.localizedDescription)
        }
    }

    public func loadChainMeta(alarmId: UUID) -> ChainMeta? {
        let key = makeMetaKey(for: alarmId)

        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            let meta = try JSONDecoder().decode(ChainMeta.self, from: data)
            os_log("Loaded chain metadata for alarm %@ (start: %@, count: %d)",
                   log: log, type: .debug, alarmId.uuidString,
                   meta.start.ISO8601Format(), meta.count)
            return meta
        } catch {
            os_log("Failed to decode chain metadata for alarm %@: %@",
                   log: log, type: .error, alarmId.uuidString, error.localizedDescription)
            return nil
        }
    }

    public func clearChainMeta(alarmId: UUID) {
        let key = makeMetaKey(for: alarmId)
        defaults.removeObject(forKey: key)

        os_log("Cleared chain metadata for alarm %@",
               log: log, type: .info, alarmId.uuidString)
    }

    // MARK: - Private Helpers

    private func makeKey(for alarmId: UUID) -> String {
        return "\(keyPrefix)_\(alarmId.uuidString)"
    }

    private func makeMetaKey(for alarmId: UUID) -> String {
        return "\(metaKeyPrefix)_\(alarmId.uuidString)"
    }

    private func updateGlobalIndex() {
        // Aggregate all identifiers across all alarms
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter {
            $0.hasPrefix(keyPrefix) && $0 != globalKey
        }

        var allIdentifiers: [String] = []

        for key in notificationKeys {
            if let identifiers = defaults.stringArray(forKey: key) {
                allIdentifiers.append(contentsOf: identifiers)
            }
        }

        os_log("Updating global index with %d total identifiers from %d alarms",
               log: log, type: .debug, allIdentifiers.count, notificationKeys.count)

        if allIdentifiers.isEmpty {
            defaults.removeObject(forKey: globalKey)
        } else {
            defaults.set(allIdentifiers, forKey: globalKey)
        }
    }
}

// MARK: - Convenience Extensions

extension NotificationIndex {
    public func saveIdentifierBatch(_ batch: NotificationIdentifierBatch) {
        saveIdentifiers(alarmId: batch.alarmId, identifiers: batch.stringValues)
    }

    public func loadIdentifierBatch(alarmId: UUID) -> NotificationIdentifierBatch {
        let identifiers = loadIdentifiers(alarmId: alarmId)
        let parsedIdentifiers = identifiers.compactMap(NotificationIdentifier.parse)
        return NotificationIdentifierBatch(alarmId: alarmId, identifiers: parsedIdentifiers)
    }

    public func idempotentReschedule(
        alarmId: UUID,
        expectedIdentifiers: [String],
        completion: () -> Void
    ) {
        // Load current identifiers
        let currentIdentifiers = loadIdentifiers(alarmId: alarmId)

        os_log("Idempotent reschedule for alarm %@: current=%d expected=%d",
               log: log, type: .info, alarmId.uuidString,
               currentIdentifiers.count, expectedIdentifiers.count)

        // Clear current identifiers first
        clearIdentifiers(alarmId: alarmId)

        // Execute the reschedule operation
        completion()

        // Save the new expected identifiers
        saveIdentifiers(alarmId: alarmId, identifiers: expectedIdentifiers)
    }
}