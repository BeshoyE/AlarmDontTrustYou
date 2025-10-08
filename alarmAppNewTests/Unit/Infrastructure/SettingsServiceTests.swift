//
//  SettingsServiceTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/2/25.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class SettingsServiceTests: XCTestCase {

    var sut: SettingsService!
    var mockUserDefaults: UserDefaults!
    var mockAudioEngine: MockAlarmAudioEngine!

    override func setUp() async throws {
        // Use in-memory UserDefaults for testing
        mockUserDefaults = UserDefaults(suiteName: "test.settings.\(UUID().uuidString)")!
        mockAudioEngine = MockAlarmAudioEngine()
        sut = SettingsService(userDefaults: mockUserDefaults, audioEngine: mockAudioEngine)
    }

    override func tearDown() async throws {
        if let suiteName = mockUserDefaults.dictionaryRepresentation().keys.first {
            mockUserDefaults.removePersistentDomain(forName: suiteName)
        }
        sut = nil
        mockUserDefaults = nil
        mockAudioEngine = nil
    }

    // MARK: - Audio Enhancement Settings Tests

    func test_audioEnhancement_defaultsToFalse() {
        XCTAssertFalse(sut.useAudioEnhancement, "Audio enhancement should default to false")
    }

    func test_audioEnhancement_cannotEnableInNotificationsOnlyMode() {
        // Given: notifications-only mode
        sut.setReliabilityMode(.notificationsOnly)

        // When: attempt to enable audio enhancement
        sut.setUseAudioEnhancement(true)

        // Then: should remain false (mode gate blocks it)
        XCTAssertFalse(sut.useAudioEnhancement, "Cannot enable audio enhancement in notifications-only mode")
    }

    func test_audioEnhancement_canEnableInNotificationsPlusAudioMode() {
        // Given: notifications+audio mode
        sut.setReliabilityMode(.notificationsPlusAudio)

        // When: enable audio enhancement
        sut.setUseAudioEnhancement(true)

        // Then: should be enabled
        XCTAssertTrue(sut.useAudioEnhancement, "Can enable audio enhancement in notifications+audio mode")
    }

    func test_audioEnhancement_persistsToUserDefaults() {
        // Given: notifications+audio mode
        sut.setReliabilityMode(.notificationsPlusAudio)

        // When: enable and persist
        sut.setUseAudioEnhancement(true)

        // Then: value should be in UserDefaults
        XCTAssertTrue(mockUserDefaults.bool(forKey: "com.alarmApp.useAudioEnhancement"))
    }

    // MARK: - Alert Intervals Validation Tests

    func test_alertIntervals_defaultsToZeroTenTwenty() {
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20], "Alert intervals should default to [0, 10, 20]")
    }

    func test_alertIntervals_rejectUnsortedArray() {
        // Given: unsorted array
        let unsorted = [10, 0, 20]

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setAlertIntervals(unsorted)) { error in
            XCTAssertEqual(error as? SettingsError, .intervalsNotSorted)
        }

        // Verify original value unchanged
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20])
    }

    func test_alertIntervals_rejectNegativeValues() {
        // Given: array with negative values
        let negative = [-5, 0, 10]

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setAlertIntervals(negative)) { error in
            XCTAssertEqual(error as? SettingsError, .invalidInterval)
        }
    }

    func test_alertIntervals_acceptSortedValidArray() throws {
        // Given: sorted valid array
        let valid = [0, 5, 15, 30]

        // When: set intervals
        try sut.setAlertIntervals(valid)

        // Then: should be accepted
        XCTAssertEqual(sut.alertIntervalsSec, valid)
    }

    func test_alertIntervals_persistsToUserDefaults() throws {
        // Given: valid intervals
        let valid = [0, 15, 30]

        // When: set and persist
        try sut.setAlertIntervals(valid)

        // Then: should be in UserDefaults
        let persisted = mockUserDefaults.array(forKey: "com.alarmApp.alertIntervalsSec") as? [Int]
        XCTAssertEqual(persisted, valid)
    }

    // MARK: - Lead-In Validation Tests

    func test_leadIn_defaultsToTwoSeconds() {
        XCTAssertEqual(sut.leadInSec, 2, "Lead-in should default to 2 seconds")
    }

    func test_leadIn_rejectNegativeValue() {
        // Given: negative value
        let negative = -5

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setLeadInSec(negative)) { error in
            XCTAssertEqual(error as? SettingsError, .leadInOutOfRange)
        }
    }

    func test_leadIn_rejectValueAbove60() {
        // Given: value > 60
        let tooLarge = 61

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setLeadInSec(tooLarge)) { error in
            XCTAssertEqual(error as? SettingsError, .leadInOutOfRange)
        }
    }

    func test_leadIn_acceptZero() throws {
        // When: set to 0
        try sut.setLeadInSec(0)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, 0)
    }

    func test_leadIn_acceptSixty() throws {
        // When: set to 60
        try sut.setLeadInSec(60)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, 60)
    }

    func test_leadIn_acceptValidMidrangeValue() throws {
        // Given: valid mid-range value
        let valid = 30

        // When: set value
        try sut.setLeadInSec(valid)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, valid)
    }

    // MARK: - Suppress Foreground Sound Tests

    func test_suppressForegroundSound_defaultsToTrue() {
        XCTAssertTrue(sut.suppressForegroundSound, "Suppress foreground sound should default to true")
    }

    func test_suppressForegroundSound_canToggle() {
        // When: toggle off
        sut.setSuppressForegroundSound(false)

        // Then: should be false
        XCTAssertFalse(sut.suppressForegroundSound)

        // When: toggle back on
        sut.setSuppressForegroundSound(true)

        // Then: should be true
        XCTAssertTrue(sut.suppressForegroundSound)
    }

    // MARK: - Reset to Defaults Test

    func test_resetToDefaults_restoresAllSettings() throws {
        // Given: modified settings
        sut.setReliabilityMode(.notificationsPlusAudio)
        sut.setUseAudioEnhancement(true)
        try sut.setAlertIntervals([0, 30, 60])
        sut.setSuppressForegroundSound(false)
        try sut.setLeadInSec(10)

        // When: reset
        sut.resetToDefaults()

        // Then: all should be back to defaults
        XCTAssertEqual(sut.currentMode, .notificationsOnly)
        XCTAssertFalse(sut.useAudioEnhancement)
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20])
        XCTAssertTrue(sut.suppressForegroundSound)
        XCTAssertEqual(sut.leadInSec, 2)
    }
}
