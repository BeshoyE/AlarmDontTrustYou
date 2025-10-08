//
//  DismissedRegistry.swift
//  alarmAppNew
//
//  Tracks dismissed alarm occurrences to prevent duplicate dismissal flows
//

import Foundation

/// Registry tracking which alarm occurrences have been successfully dismissed
/// Prevents re-showing dismissal flow on app restart when delivered notifications persist
@MainActor
final class DismissedRegistry {
    private struct DismissedOccurrence: Codable {
        let alarmId: UUID
        let occurrenceKey: String
        let dismissedAt: Date
    }

    private let userDefaults: UserDefaults
    private let storageKey = "com.alarmapp.dismissedOccurrences"
    private let expirationWindow: TimeInterval = 300  // 5 minutes

    private var cache: [String: DismissedOccurrence] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCache()
    }

    /// Mark an occurrence as dismissed (pure persistence - no OS cleanup)
    func markDismissed(alarmId: UUID, occurrenceKey: String) {
        let key = cacheKey(alarmId: alarmId, occurrenceKey: occurrenceKey)
        let occurrence = DismissedOccurrence(
            alarmId: alarmId,
            occurrenceKey: occurrenceKey,
            dismissedAt: Date()
        )

        cache[key] = occurrence
        persistCache()

        let alarmIdPrefix = String(alarmId.uuidString.prefix(8))
        let keyPrefix = String(occurrenceKey.prefix(10))
        print("📋 DismissedRegistry: Marked", alarmIdPrefix + "/" + keyPrefix + "...", "as dismissed")
    }

    /// Check if an occurrence was already dismissed recently
    func isDismissed(alarmId: UUID, occurrenceKey: String) -> Bool {
        let key = cacheKey(alarmId: alarmId, occurrenceKey: occurrenceKey)

        guard let occurrence = cache[key] else {
            return false
        }

        // Check if dismissal is still within expiration window
        let isExpired = Date().timeIntervalSince(occurrence.dismissedAt) > expirationWindow
        if isExpired {
            // Clean up expired entry
            cache.removeValue(forKey: key)
            persistCache()
            return false
        }

        return true
    }

    /// Get all dismissed occurrence keys for startup cleanup
    func dismissedOccurrenceKeys() -> Set<String> {
        return Set(cache.values.map { $0.occurrenceKey })
    }

    /// Clear all dismissed occurrences (for testing/reset)
    func clearAll() {
        cache.removeAll()
        userDefaults.removeObject(forKey: storageKey)
        print("📋 DismissedRegistry: Cleared all dismissed occurrences")
    }

    /// Clean up expired occurrences (call periodically)
    func cleanupExpired() {
        let now = Date()
        let expiredKeys = cache.filter { _, occurrence in
            now.timeIntervalSince(occurrence.dismissedAt) > expirationWindow
        }.map { $0.key }

        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }

        if !expiredKeys.isEmpty {
            persistCache()
            print("📋 DismissedRegistry: Cleaned up \(expiredKeys.count) expired occurrences")
        }
    }

    // MARK: - Private Helpers

    private func cacheKey(alarmId: UUID, occurrenceKey: String) -> String {
        return "\(alarmId.uuidString)|\(occurrenceKey)"
    }

    private func loadCache() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: DismissedOccurrence].self, from: data) else {
            return
        }

        cache = decoded
        cleanupExpired()  // Clean on load
    }

    private func persistCache() {
        guard let encoded = try? JSONEncoder().encode(cache) else {
            print("⚠️ DismissedRegistry: Failed to encode cache")
            return
        }

        userDefaults.set(encoded, forKey: storageKey)
    }
}
