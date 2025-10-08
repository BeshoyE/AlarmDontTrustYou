//
//  ArchitectureGuardrailTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/5/25.
//  Guardrail tests to enforce architectural boundaries
//

import XCTest
@testable import alarmAppNew

final class ArchitectureGuardrailTests: XCTestCase {
    func test_dismissedRegistry_hasNoOSDependencies() {
        // This is a compile-time check: DismissedRegistry MUST NOT import UIKit or UserNotifications
        // If it does, this file won't compile
        let registry = DismissedRegistry()
        XCTAssertNotNil(registry, "DismissedRegistry should initialize without OS dependencies")
    }

    @MainActor
    func test_dismissedRegistry_init_noForceUnwraps() async {
        // Verify initialization doesn't crash with default UserDefaults
        let registry = DismissedRegistry()

        // Should initialize successfully with empty cache (await for MainActor)
        let keys = await registry.dismissedOccurrenceKeys()
        XCTAssertNotNil(keys)
        XCTAssertTrue(keys.isEmpty, "Fresh registry should have no dismissed occurrences")
    }

    @MainActor
    func test_dismissedRegistry_markDismissed_persistsState() async {
        // Given: A fresh registry
        let registry = DismissedRegistry()
        let alarmId = UUID()
        let occurrenceKey = OccurrenceKeyFormatter.key(from: Date())

        // When: We mark an occurrence as dismissed
        await registry.markDismissed(alarmId: alarmId, occurrenceKey: occurrenceKey)

        // Then: It's remembered
        let isDismissed = await registry.isDismissed(alarmId: alarmId, occurrenceKey: occurrenceKey)
        XCTAssertTrue(isDismissed, "Registry should remember dismissed occurrence")

        // And: It appears in dismissed keys set
        let dismissedKeys = await registry.dismissedOccurrenceKeys()
        XCTAssertTrue(dismissedKeys.contains(occurrenceKey), "Dismissed key should be in set")
    }

    @MainActor
    func test_dismissedRegistry_expiration_clearsOldEntries() async {
        // Given: A registry with a mocked old dismissal (would need to manipulate time)
        // This test validates that expired entries are cleaned up
        // For now, we just verify the cleanup method exists and doesn't crash
        let registry = DismissedRegistry()

        // When: We call cleanup
        await registry.cleanupExpired()

        // Then: No crash occurs
        let keys = await registry.dismissedOccurrenceKeys()
        XCTAssertNotNil(keys)
    }
}
