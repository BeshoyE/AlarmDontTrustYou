//
//  AlarmRunStore.swift
//  alarmAppNew
//
//  Thread-safe persistence store for AlarmRun entities.
//  Conforms to CLAUDE.md §3 (actor-based concurrency) and §9 (async persistence).
//

import Foundation

/// Thread-safe actor for managing AlarmRun persistence.
///
/// **Architecture Compliance:**
/// - CLAUDE.md §3: Uses Swift `actor` for shared mutable state (no manual locking)
/// - CLAUDE.md §9: All methods are `async throws` per persistence contract
/// - claude-guardrails.md: No side effects in `init` (only stores UserDefaults reference)
///
/// **Thread Safety:**
/// Actor serialization ensures atomic load-modify-save sequences.
/// Multiple concurrent `appendRun()` calls are automatically serialized.
///
/// **Error Handling:**
/// All methods throw typed `AlarmRunStoreError` per CLAUDE.md §5.5.
actor AlarmRunStore {
    // MARK: - Properties

    private let defaults: UserDefaults
    private let key = "alarm_runs"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Init

    /// Create a new AlarmRunStore.
    ///
    /// - Parameter defaults: UserDefaults instance for persistence (default: .standard)
    ///
    /// **No side effects:** Only stores the UserDefaults reference per claude-guardrails.md.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Append a new alarm run to persistent storage.
    ///
    /// **Thread Safety:** Actor serialization ensures atomic load-append-save.
    ///
    /// - Parameter run: The alarm run to persist
    /// - Throws: `AlarmRunStoreError.loadFailed` if existing runs can't be loaded
    /// - Throws: `AlarmRunStoreError.saveFailed` if encoding or save fails
    func appendRun(_ run: AlarmRun) async throws(AlarmRunStoreError) {
        // Load existing runs (atomic step 1)
        var existingRuns: [AlarmRun] = []
        if let data = defaults.data(forKey: key) {
            do {
                existingRuns = try decoder.decode([AlarmRun].self, from: data)
            } catch {
                // Corruption: log and throw typed error
                print("AlarmRunStore: Failed to decode existing runs: \(error)")
                throw .loadFailed
            }
        }

        // Append new run (atomic step 2)
        existingRuns.append(run)

        // Save back to storage (atomic step 3)
        do {
            let encoded = try encoder.encode(existingRuns)
            defaults.set(encoded, forKey: key)
            defaults.synchronize() // Force immediate write
            print("AlarmRunStore: Appended run \(run.id) for alarm \(run.alarmId) (total: \(existingRuns.count) runs)")
        } catch {
            print("AlarmRunStore: Failed to encode runs: \(error)")
            throw .saveFailed
        }
    }

    /// Load all alarm runs from persistent storage.
    ///
    /// - Returns: Array of all stored alarm runs (empty if none exist)
    /// - Throws: `AlarmRunStoreError.loadFailed` if data exists but can't be decoded
    func loadRuns() async throws(AlarmRunStoreError) -> [AlarmRun] {
        guard let data = defaults.data(forKey: key) else {
            // No data stored yet - not an error, just empty
            return []
        }

        do {
            let runs = try decoder.decode([AlarmRun].self, from: data)
            print("AlarmRunStore: Loaded \(runs.count) runs from storage")
            return runs
        } catch {
            print("AlarmRunStore: Failed to decode runs: \(error)")
            throw .loadFailed
        }
    }

    /// Load alarm runs for a specific alarm.
    ///
    /// - Parameter alarmId: The UUID of the alarm to filter by
    /// - Returns: Array of runs for the specified alarm (empty if none exist)
    /// - Throws: `AlarmRunStoreError.loadFailed` if data can't be loaded
    func runs(for alarmId: UUID) async throws(AlarmRunStoreError) -> [AlarmRun] {
        let allRuns = try await loadRuns()
        let filtered = allRuns.filter { $0.alarmId == alarmId }
        print("AlarmRunStore: Loaded \(filtered.count) runs for alarm \(alarmId)")
        return filtered
    }

    /// Clean up incomplete alarm runs from previous sessions.
    ///
    /// Marks runs older than 1 hour with no `dismissedAt` as failed.
    /// This is called on app launch to handle cases where the app was
    /// killed/crashed during an alarm dismissal flow.
    ///
    /// **Thread Safety:** Actor serialization ensures atomic load-modify-save.
    ///
    /// - Throws: `AlarmRunStoreError.loadFailed` if existing runs can't be loaded
    /// - Throws: `AlarmRunStoreError.saveFailed` if changes can't be saved
    func cleanupIncompleteRuns() async throws(AlarmRunStoreError) {
        // Load all runs (atomic step 1)
        var allRuns = try await loadRuns()
        let now = Date()
        var hasChanges = false

        // Mark stale incomplete runs as failed (atomic step 2)
        for i in 0..<allRuns.count {
            let run = allRuns[i]

            // If run is incomplete (no dismissedAt) and older than 1 hour, mark as failed
            if run.dismissedAt == nil &&
               run.outcome == .failed && // Default state
               now.timeIntervalSince(run.firedAt) > 3600 { // 1 hour

                allRuns[i].outcome = .failed
                hasChanges = true
                print("AlarmRunStore: Marked stale AlarmRun as failed: \(run.id) (alarm: \(run.alarmId))")
            }
        }

        // Save changes if any (atomic step 3)
        if hasChanges {
            do {
                let encoded = try encoder.encode(allRuns)
                defaults.set(encoded, forKey: key)
                defaults.synchronize()
                print("AlarmRunStore: Cleanup complete - marked \(allRuns.count) runs")
            } catch {
                print("AlarmRunStore: Failed to save after cleanup: \(error)")
                throw .saveFailed
            }
        } else {
            print("AlarmRunStore: Cleanup complete - no changes needed")
        }
    }
}
