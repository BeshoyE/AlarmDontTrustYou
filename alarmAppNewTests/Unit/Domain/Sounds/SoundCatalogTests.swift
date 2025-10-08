//
//  SoundCatalogTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/24/25.
//

import XCTest
@testable import alarmAppNew

final class SoundCatalogTests: XCTestCase {

    // MARK: - Validation Tests

    func testSoundCatalog_validate_uniqueIds() {
        // Given: A catalog with file validation disabled for testing
        let catalog = SoundCatalog(validateFiles: false)

        // When: We get all sounds
        let allSounds = catalog.all

        // Then: All IDs should be unique
        let uniqueIds = Set(allSounds.map { $0.id })
        XCTAssertEqual(uniqueIds.count, allSounds.count, "All sound IDs must be unique")
    }

    func testSoundCatalog_validate_positiveDurations() {
        // Given: A catalog with file validation disabled
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check all durations
        let allSounds = catalog.all

        // Then: All durations should be positive
        for sound in allSounds {
            XCTAssertGreaterThan(sound.durationSec, 0, "Sound '\(sound.id)' must have positive duration")
        }
    }

    func testSoundCatalog_validate_defaultSoundExists() {
        // Given: A catalog with file validation disabled
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check the default sound ID
        let defaultSoundId = catalog.defaultSoundId

        // Then: Default sound must exist in catalog
        let defaultSound = catalog.info(for: defaultSoundId)
        XCTAssertNotNil(defaultSound, "Default sound ID '\(defaultSoundId)' must exist in catalog")
    }

    // MARK: - Lookup Tests

    func testSoundCatalog_info_returnsCorrectSound() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up the guaranteed "chimes01" sound
        let sound = catalog.info(for: "chimes01")

        // Then: We should get the correct sound with proper identity and invariants
        XCTAssertNotNil(sound, "chimes01 must exist in catalog")
        XCTAssertEqual(sound?.id, "chimes01", "Sound ID must match lookup key")

        // Test basic invariants (not specific values to avoid brittleness)
        XCTAssertFalse(sound?.name.isEmpty ?? true, "Sound name cannot be empty")
        XCTAssertFalse(sound?.fileName.isEmpty ?? true, "Sound fileName cannot be empty")
        XCTAssertGreaterThan(sound?.durationSec ?? 0, 0, "Sound duration must be positive")

        // Verify the sound has reasonable properties for an alarm sound
        if let name = sound?.name {
            XCTAssertTrue(name.count > 2, "Sound name should be descriptive")
        }
        if let fileName = sound?.fileName {
            XCTAssertTrue(fileName.hasSuffix(".caf") || fileName.hasSuffix(".mp3") || fileName.hasSuffix(".wav"),
                         "Sound fileName should have audio extension")
        }
    }

    func testSoundCatalog_info_unknownIdReturnsNil() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up a non-existent sound ID
        let sound = catalog.info(for: "unknown-sound-id")

        // Then: We should get nil
        XCTAssertNil(sound)
    }

    // MARK: - Safe Helper Tests

    func testSoundCatalog_safeInfo_validIdReturnsSound() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with a valid ID
        let sound = catalog.safeInfo(for: "chimes01")

        // Then: We should get the correct sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, "chimes01")
    }

    func testSoundCatalog_safeInfo_invalidIdFallsBackToDefault() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with an invalid ID
        let sound = catalog.safeInfo(for: "invalid-id")

        // Then: We should get the default sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, catalog.defaultSoundId)
    }

    func testSoundCatalog_safeInfo_nilIdFallsBackToDefault() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with nil
        let sound = catalog.safeInfo(for: nil)

        // Then: We should get the default sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, catalog.defaultSoundId)
    }

    // MARK: - Guaranteed Content Tests

    func testSoundCatalog_guaranteedChimes01Exists() {
        // Given: A catalog (this is critical for migration safety)
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up the hardcoded fallback ID used in Alarm.init(from:)
        let sound = catalog.info(for: "chimes01")

        // Then: This sound MUST exist to prevent runtime crashes
        XCTAssertNotNil(sound, "chimes01 must exist - it's the hardcoded fallback in Alarm migration")
        XCTAssertEqual(sound?.id, "chimes01")
    }

    func testSoundCatalog_allSoundsHaveValidProperties() {
        // Given: A catalog with all sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check all sounds
        let allSounds = catalog.all

        // Then: All sounds should have valid properties
        XCTAssertGreaterThan(allSounds.count, 0, "Catalog must have at least one sound")

        for sound in allSounds {
            XCTAssertFalse(sound.id.isEmpty, "Sound ID cannot be empty")
            XCTAssertFalse(sound.name.isEmpty, "Sound name cannot be empty")
            XCTAssertFalse(sound.fileName.isEmpty, "Sound fileName cannot be empty")
            XCTAssertGreaterThan(sound.durationSec, 0, "Sound duration must be positive")
            XCTAssertLessThanOrEqual(sound.durationSec, 30, "Sound duration should be ≤30s for iOS notifications")
        }
    }

    // MARK: - Test Helpers

    private func encodedAlarmsByPatchingSoundId(
        from alarm: Alarm,
        to newValue: String?,
        removeKey: Bool = false
    ) throws -> Data {
        let original = try JSONEncoder().encode([alarm])
        guard var arr = try JSONSerialization.jsonObject(with: original) as? [[String: Any]] else {
            throw NSError(domain: "TestPatch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse encoded alarm as JSON array"])
        }
        var dict = arr[0]
        if removeKey {
            dict.removeValue(forKey: "soundId")
        } else if let newValue {
            dict["soundId"] = newValue
        }
        arr[0] = dict
        return try JSONSerialization.data(withJSONObject: arr, options: [])
    }

    // MARK: - Persistence Repair Tests

    func testPersistenceService_repairInvalidSoundId_sticks() {
        // Given: In-memory UserDefaults suite for isolation
        let suiteName = "test-\(UUID().uuidString)"
        let testSuite = UserDefaults(suiteName: suiteName)!
        defer { testSuite.removePersistentDomain(forName: suiteName) }

        let catalog = SoundCatalog(validateFiles: false)
        let persistence = PersistenceService(defaults: testSuite, soundCatalog: catalog)

        // Create a valid alarm then patch soundId to invalid value (encode-then-patch approach)
        let validAlarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "bells01", // Start with valid soundId
            soundName: nil,
            volume: 0.8
        )

        do {
            // Encode alarm properly, then patch soundId to invalid value
            let patchedData = try encodedAlarmsByPatchingSoundId(from: validAlarm, to: "invalid-sound-id")
            testSuite.set(patchedData, forKey: "savedAlarms")

            // When: First load triggers automatic repair
            let alarmsFirstLoad = try persistence.loadAlarms()

            // Then: soundId should be automatically repaired
            XCTAssertEqual(alarmsFirstLoad[0].soundId, catalog.defaultSoundId, "soundId should be automatically repaired to default")

            // When: Second load to verify repair persistence
            let alarmsSecondLoad = try persistence.loadAlarms()

            // Then: Should remain repaired (no infinite loop)
            XCTAssertEqual(alarmsSecondLoad[0].soundId, catalog.defaultSoundId, "Repair should stick - no infinite loop")

            // Verify the repaired data is actually saved to storage
            if let savedData = testSuite.data(forKey: "savedAlarms") {
                let savedAlarms = try JSONDecoder().decode([Alarm].self, from: savedData)
                XCTAssertEqual(savedAlarms[0].soundId, catalog.defaultSoundId, "Repaired soundId should be persisted")
            } else {
                XCTFail("Expected saved alarms data to exist after repair")
            }
        } catch {
            XCTFail("Test setup or repair should not throw: \(error)")
        }
    }

    func testPersistenceService_repairMissingSoundId_usesDecoder() {
        // Given: In-memory UserDefaults suite
        let suiteName = "test-\(UUID().uuidString)"
        let testSuite = UserDefaults(suiteName: suiteName)!
        defer { testSuite.removePersistentDomain(forName: suiteName) }

        let catalog = SoundCatalog(validateFiles: false)
        let persistence = PersistenceService(defaults: testSuite, soundCatalog: catalog)

        // Create a valid alarm then remove soundId field (encode-then-patch approach)
        let validAlarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Old Format Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "bells01", // Start with valid soundId
            soundName: nil,
            volume: 0.5
        )

        do {
            // Encode alarm properly, then remove soundId field (simulates old format)
            let patchedData = try encodedAlarmsByPatchingSoundId(from: validAlarm, to: nil, removeKey: true)
            testSuite.set(patchedData, forKey: "savedAlarms")

            // When: Load alarms (decoder should handle missing soundId)
            let loadedAlarms = try persistence.loadAlarms()

            // Then: Decoder fallback should provide chimes01
            XCTAssertEqual(loadedAlarms.count, 1)
            XCTAssertEqual(loadedAlarms[0].soundId, "chimes01", "Decoder should fallback to chimes01 for missing soundId")
        } catch {
            XCTFail("Test setup or loading should not throw: \(error)")
        }
    }

    // MARK: - Critical Encode/Decode Tests

    func testAlarm_encodeDecode_preservesSoundId() {
        // Given: Alarm with specific soundId
        let originalSoundId = "bells01"
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [.monday],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: originalSoundId,
            soundName: nil,
            volume: 0.8
        )

        // When: Encode then decode
        do {
            let encoded = try JSONEncoder().encode(alarm)
            let decoded = try JSONDecoder().decode(Alarm.self, from: encoded)

            // Then: soundId preserved exactly
            XCTAssertEqual(decoded.soundId, originalSoundId, "soundId must survive encode/decode to prevent repair loops")

            // Verify other critical fields also preserved
            XCTAssertEqual(decoded.id, alarm.id)
            XCTAssertEqual(decoded.label, alarm.label)
            XCTAssertEqual(decoded.volume, alarm.volume)
        } catch {
            XCTFail("Encode/decode should not throw: \(error)")
        }
    }

    func testAlarm_encodeDecode_preservesSoundIdWithSpecialCharacters() {
        // Given: Alarm with soundId containing special characters (edge case)
        let originalSoundId = "tone-01_special.sound"
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Special Test",
            repeatDays: [],
            challengeKind: [.qr],
            isEnabled: true,
            soundId: originalSoundId,
            volume: 0.5
        )

        // When: Encode then decode
        do {
            let encoded = try JSONEncoder().encode(alarm)
            let decoded = try JSONDecoder().decode(Alarm.self, from: encoded)

            // Then: Special characters in soundId preserved
            XCTAssertEqual(decoded.soundId, originalSoundId, "Special characters in soundId must be preserved")
        } catch {
            XCTFail("Encode/decode should not throw: \(error)")
        }
    }

    // MARK: - Preview Catalog Tests

    func testSoundCatalog_preview_isAccessible() {
        // Given: The preview catalog
        let catalog = SoundCatalog.preview

        // When: We access its properties
        let allSounds = catalog.all
        let defaultId = catalog.defaultSoundId

        // Then: It should work without file validation
        XCTAssertGreaterThan(allSounds.count, 0)
        XCTAssertNotNil(catalog.info(for: defaultId))
    }
}