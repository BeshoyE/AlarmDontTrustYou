//
//  ChainSettingsProviderTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class ChainSettingsProviderTests: XCTestCase {

    private var provider: DefaultChainSettingsProvider!

    override func setUp() {
        super.setUp()
        provider = DefaultChainSettingsProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Default Settings Tests

    func test_chainSettings_returnsValidDefaults() {
        let settings = provider.chainSettings()

        XCTAssertEqual(settings.maxChainCount, 12)
        XCTAssertEqual(settings.ringWindowSec, 300)
        XCTAssertEqual(settings.fallbackSpacingSec, 10)
        XCTAssertEqual(settings.minLeadTimeSec, 10)
    }

    func test_chainSettings_defaultsPassValidation() {
        let settings = provider.chainSettings()
        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.errorReasons, [])
    }

    // MARK: - Chain Count Validation Tests

    func test_validateSettings_chainCountTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 0,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount must be at least 1"))
    }

    func test_validateSettings_chainCountTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 20,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount should not exceed 15 (iOS notification limit considerations)"))
    }

    func test_validateSettings_validChainCount_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Ring Window Validation Tests

    func test_validateSettings_ringWindowTooSmall_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 20,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec must be at least 30 seconds"))
    }

    func test_validateSettings_ringWindowTooLarge_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 700,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec should not exceed 600 seconds (10 minutes)"))
    }

    // MARK: - Fallback Spacing Validation Tests

    func test_validateSettings_fallbackSpacingTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 3
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec must be at least 5 seconds"))
    }

    func test_validateSettings_fallbackSpacingTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 70
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec should not exceed 60 seconds"))
    }

    // MARK: - Minimum Lead Time Validation Tests

    func test_validateSettings_minLeadTimeTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 3
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("minLeadTimeSec must be at least 5 seconds"))
    }

    func test_validateSettings_minLeadTimeTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 40
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("minLeadTimeSec should not exceed 30 seconds"))
    }

    func test_validateSettings_minLeadTimeValid_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 15
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Cross-Validation Tests

    func test_validateSettings_ringWindowTooSmallForChain_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 10,
            ringWindowSec: 100, // 10 * 30 = 300, but ring window is only 100
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec too small for maxChainCount at fallbackSpacingSec"))
    }

    func test_validateSettings_ringWindowJustEnoughForChain_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 150, // 5 * 30 = 150, exactly enough
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Multiple Errors Tests

    func test_validateSettings_multipleErrors_returnsAllReasons() {
        let settings = ChainSettings(
            maxChainCount: 0, // Too low
            ringWindowSec: 20, // Too small
            fallbackSpacingSec: 70 // Too high
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertGreaterThan(validation.errorReasons.count, 2)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount must be at least 1"))
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec must be at least 30 seconds"))
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec should not exceed 60 seconds"))
    }

    // MARK: - Validation Result Tests

    func test_validationResult_validCase_hasCorrectProperties() {
        let result = ChainSettingsValidationResult.valid

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.errorReasons, [])
    }

    func test_validationResult_invalidCase_hasCorrectProperties() {
        let reasons = ["Error 1", "Error 2"]
        let result = ChainSettingsValidationResult.invalid(reasons: reasons)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorReasons, reasons)
    }

    // MARK: - Edge Cases

    func test_validateSettings_minimumValidConfiguration_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 1,
            ringWindowSec: 30,
            fallbackSpacingSec: 5
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    func test_validateSettings_maximumValidConfiguration_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 10,
            ringWindowSec: 600,
            fallbackSpacingSec: 60
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }
}