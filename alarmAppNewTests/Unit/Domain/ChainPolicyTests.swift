//
//  ChainPolicyTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class ChainPolicyTests: XCTestCase {

    // MARK: - ChainSettings Validation Tests

    func test_chainSettings_defaultValues_withinValidRanges() {
        let settings = ChainSettings()

        XCTAssertEqual(settings.maxChainCount, 12)
        XCTAssertEqual(settings.ringWindowSec, 180)
        XCTAssertEqual(settings.fallbackSpacingSec, 30)
        XCTAssertEqual(settings.minLeadTimeSec, 10)
    }

    func test_chainSettings_clampsExcessiveValues() {
        let settings = ChainSettings(
            maxChainCount: 100,  // Should clamp to 50
            ringWindowSec: 1000, // Should clamp to 600
            fallbackSpacingSec: 60, // Should clamp to 30
            minLeadTimeSec: 100 // Should clamp to 30
        )

        XCTAssertEqual(settings.maxChainCount, 50)
        XCTAssertEqual(settings.ringWindowSec, 600)
        XCTAssertEqual(settings.fallbackSpacingSec, 30)
        XCTAssertEqual(settings.minLeadTimeSec, 30)
    }

    func test_chainSettings_clampsNegativeValues() {
        let settings = ChainSettings(
            maxChainCount: -5,   // Should clamp to 1
            ringWindowSec: -10,  // Should clamp to 30
            fallbackSpacingSec: 0, // Should clamp to 1
            minLeadTimeSec: -1   // Should clamp to 5
        )

        XCTAssertEqual(settings.maxChainCount, 1)
        XCTAssertEqual(settings.ringWindowSec, 30)
        XCTAssertEqual(settings.fallbackSpacingSec, 1)
        XCTAssertEqual(settings.minLeadTimeSec, 5)
    }

    // MARK: - ChainPolicy Normalization Tests

    func test_chainPolicy_normalizedSpacing_clampsToValidRange() {
        let policy = ChainPolicy()

        // Test lower bound
        XCTAssertEqual(policy.normalizedSpacing(0), 1)
        XCTAssertEqual(policy.normalizedSpacing(-5), 1)

        // Test upper bound
        XCTAssertEqual(policy.normalizedSpacing(35), 30)
        XCTAssertEqual(policy.normalizedSpacing(60), 30)

        // Test valid values
        XCTAssertEqual(policy.normalizedSpacing(5), 5)
        XCTAssertEqual(policy.normalizedSpacing(15), 15)
        XCTAssertEqual(policy.normalizedSpacing(30), 30)
    }

    // MARK: - Chain Computation Tests

    func test_chainPolicy_computeChain_standardSpacing() {
        let settings = ChainSettings(maxChainCount: 10, ringWindowSec: 180, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 30)

        XCTAssertEqual(config.spacingSeconds, 30)
        XCTAssertEqual(config.chainCount, 6) // 180 / 30 = 6
        XCTAssertEqual(config.totalDurationSeconds, 180) // 30 * 6
    }

    func test_chainPolicy_computeChain_respectsMaximumLimit() {
        let settings = ChainSettings(maxChainCount: 3, ringWindowSec: 180, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 10) // Would theoretically allow 18 notifications

        XCTAssertEqual(config.spacingSeconds, 10)
        XCTAssertEqual(config.chainCount, 3) // Capped at maxChainCount
        XCTAssertEqual(config.totalDurationSeconds, 30) // 10 * 3
    }

    func test_chainPolicy_computeChain_ensuresMinimumOne() {
        let settings = ChainSettings(maxChainCount: 12, ringWindowSec: 10, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 60) // 10 / 60 = 0, but should be at least 1

        XCTAssertEqual(config.spacingSeconds, 30) // Normalized from 60 to max 30
        XCTAssertEqual(config.chainCount, 1) // At least 1, even if window is too small
    }

    func test_chainPolicy_computeChain_shortSpacing() {
        let settings = ChainSettings(maxChainCount: 12, ringWindowSec: 60, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 5)

        XCTAssertEqual(config.spacingSeconds, 5)
        XCTAssertEqual(config.chainCount, 12) // 60 / 5 = 12, exactly at limit
    }

    // MARK: - Fire Date Computation Tests

    func test_chainPolicy_computeFireDates_correctIntervals() {
        let policy = ChainPolicy()
        let baseDate = Date(timeIntervalSince1970: 1000000) // Fixed reference point
        let config = ChainConfiguration(spacingSeconds: 30, chainCount: 3)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 3)
        XCTAssertEqual(fireDates[0], baseDate) // k=0: no offset
        XCTAssertEqual(fireDates[1], baseDate.addingTimeInterval(30)) // k=1: +30s
        XCTAssertEqual(fireDates[2], baseDate.addingTimeInterval(60)) // k=2: +60s
    }

    func test_chainPolicy_computeFireDates_singleNotification() {
        let policy = ChainPolicy()
        let baseDate = Date(timeIntervalSince1970: 2000000)
        let config = ChainConfiguration(spacingSeconds: 15, chainCount: 1)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 1)
        XCTAssertEqual(fireDates[0], baseDate)
    }

    func test_chainPolicy_computeFireDates_monotonicIncreasing() {
        let policy = ChainPolicy()
        let baseDate = Date()
        let config = ChainConfiguration(spacingSeconds: 20, chainCount: 5)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 5)

        // Verify dates are strictly increasing
        for i in 1..<fireDates.count {
            XCTAssertLessThan(fireDates[i-1], fireDates[i])

            // Verify exact spacing
            let expectedInterval = TimeInterval(i * config.spacingSeconds)
            let actualInterval = fireDates[i].timeIntervalSince(baseDate)
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 0.001)
        }
    }

    // MARK: - ChainConfiguration Trimming Tests

    func test_chainConfiguration_trimmed_reducesCount() {
        let config = ChainConfiguration(spacingSeconds: 10, chainCount: 8)
        let trimmed = config.trimmed(to: 5)

        XCTAssertEqual(trimmed.spacingSeconds, 10) // Unchanged
        XCTAssertEqual(trimmed.chainCount, 5) // Reduced
        XCTAssertEqual(trimmed.totalDurationSeconds, 50) // 10 * 5
    }

    func test_chainConfiguration_trimmed_respectsMinimumOne() {
        let config = ChainConfiguration(spacingSeconds: 25, chainCount: 4)
        let trimmed = config.trimmed(to: 0) // Should still be at least 1

        XCTAssertEqual(trimmed.spacingSeconds, 25)
        XCTAssertEqual(trimmed.chainCount, 1)
        XCTAssertEqual(trimmed.totalDurationSeconds, 25)
    }

    func test_chainConfiguration_trimmed_noChangeIfWithinLimit() {
        let config = ChainConfiguration(spacingSeconds: 15, chainCount: 3)
        let trimmed = config.trimmed(to: 5) // Limit higher than current count

        XCTAssertEqual(trimmed.spacingSeconds, 15)
        XCTAssertEqual(trimmed.chainCount, 3) // Unchanged
        XCTAssertEqual(trimmed.totalDurationSeconds, 45)
    }

    // MARK: - DST Boundary Edge Case Tests

    func test_chainPolicy_dstBoundary_springForward() {
        let policy = ChainPolicy()

        // March 10, 2024 at 1:30 AM (before spring forward in most US timezones)
        let calendar = Calendar.current
        let beforeDST = calendar.date(from: DateComponents(
            year: 2024, month: 3, day: 10, hour: 1, minute: 30
        ))!

        let config = ChainConfiguration(spacingSeconds: 30, chainCount: 4)
        let fireDates = policy.computeFireDates(baseFireDate: beforeDST, configuration: config)

        XCTAssertEqual(fireDates.count, 4)

        // Verify intervals remain consistent even across DST boundary
        for i in 1..<fireDates.count {
            let interval = fireDates[i].timeIntervalSince(fireDates[i-1])
            XCTAssertEqual(interval, 30.0, accuracy: 0.1) // Allow small tolerance for DST
        }
    }

    func test_chainPolicy_dstBoundary_fallBack() {
        let policy = ChainPolicy()

        // November 3, 2024 at 1:30 AM (before fall back in most US timezones)
        let calendar = Calendar.current
        let beforeDST = calendar.date(from: DateComponents(
            year: 2024, month: 11, day: 3, hour: 1, minute: 30
        ))!

        let config = ChainConfiguration(spacingSeconds: 45, chainCount: 3)
        let fireDates = policy.computeFireDates(baseFireDate: beforeDST, configuration: config)

        XCTAssertEqual(fireDates.count, 3)

        // Verify intervals remain consistent
        for i in 1..<fireDates.count {
            let interval = fireDates[i].timeIntervalSince(fireDates[i-1])
            XCTAssertEqual(interval, 45.0, accuracy: 0.1)
        }
    }

    // MARK: - Boundary Condition Tests

    func test_chainPolicy_extremeValues_handledGracefully() {
        let extremeSettings = ChainSettings(
            maxChainCount: 1,
            ringWindowSec: 30,
            fallbackSpacingSec: 1
        )
        let policy = ChainPolicy(settings: extremeSettings)

        let config = policy.computeChain(spacingSeconds: 1)

        XCTAssertEqual(config.spacingSeconds, 1)
        XCTAssertEqual(config.chainCount, 1) // Capped at max
        XCTAssertEqual(config.totalDurationSeconds, 1)
    }
}