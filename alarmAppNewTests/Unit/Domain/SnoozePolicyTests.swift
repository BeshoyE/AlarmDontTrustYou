//
//  SnoozePolicyTests.swift
//  alarmAppNewTests
//
//  Tests for snooze policies and the SnoozeAlarm use case.
//  Verifies duration clamping and DST-aware time calculations.
//

import XCTest
@testable import alarmAppNew

final class SnoozePolicyTests: XCTestCase {

    // MARK: - Duration Clamping Tests

    func test_snooze_clamps_below_min_to_min() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting snooze below minimum (1 minute)
        let requestedDuration: TimeInterval = 60 // 1 minute
        let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedDuration,
            bounds: bounds
        )

        // THEN: Should clamp to minimum (5 minutes)
        XCTAssertEqual(
            clamped,
            5 * 60,
            "Duration below minimum should be clamped to minimum"
        )
    }

    func test_snooze_clamps_above_max_to_max() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting snooze above maximum (2 hours)
        let requestedDuration: TimeInterval = 2 * 60 * 60 // 2 hours
        let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedDuration,
            bounds: bounds
        )

        // THEN: Should clamp to maximum (60 minutes)
        XCTAssertEqual(
            clamped,
            60 * 60,
            "Duration above maximum should be clamped to maximum"
        )
    }

    func test_snooze_allows_duration_within_bounds() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting valid durations
        let validDurations: [TimeInterval] = [
            5 * 60,   // Exactly minimum
            10 * 60,  // 10 minutes
            30 * 60,  // 30 minutes
            60 * 60   // Exactly maximum
        ]

        // THEN: All should remain unchanged
        for duration in validDurations {
            let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
                duration,
                bounds: bounds
            )
            XCTAssertEqual(
                clamped,
                duration,
                "Valid duration \(duration) should not be changed"
            )

            // Also verify validation
            XCTAssertTrue(
                AlarmPresentationPolicy.isSnoozeDurationValid(duration, bounds: bounds),
                "Duration \(duration) should be valid"
            )
        }
    }

    // MARK: - Snooze Bounds Tests

    func test_snooze_bounds_initialization() {
        // GIVEN: Various bounds configurations

        // Normal case
        let normal = SnoozeBounds(min: 60, max: 600)
        XCTAssertEqual(normal.min, 60)
        XCTAssertEqual(normal.max, 600)

        // Inverted bounds (max < min)
        let inverted = SnoozeBounds(min: 600, max: 60)
        XCTAssertEqual(inverted.min, 60, "Should auto-correct inverted bounds")
        XCTAssertEqual(inverted.max, 600, "Should auto-correct inverted bounds")

        // Default bounds
        let defaultBounds = SnoozeBounds.default
        XCTAssertEqual(defaultBounds.min, 5 * 60, "Default min should be 5 minutes")
        XCTAssertEqual(defaultBounds.max, 60 * 60, "Default max should be 60 minutes")
    }

    // MARK: - DST Transition Tests

    func test_snooze_computes_next_fire_on_local_clock_respecting_dst_transition() {
        // GIVEN: A test calendar and timezone that observes DST
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create alarm
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()

        // Test case 1: Spring forward (2 AM -> 3 AM)
        // March 10, 2024 at 1:45 AM EST
        var springComponents = DateComponents()
        springComponents.year = 2024
        springComponents.month = 3
        springComponents.day = 10
        springComponents.hour = 1
        springComponents.minute = 45
        springComponents.second = 0
        springComponents.timeZone = easternTimeZone

        guard let springDate = calendar.date(from: springComponents) else {
            XCTFail("Could not create spring DST test date")
            return
        }

        // WHEN: Snoozing for 30 minutes (crosses DST boundary)
        let springNextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: springDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds(min: 5 * 60, max: 60 * 60),
            calendar: calendar,
            timeZone: easternTimeZone
        )

        // THEN: Should fire at 3:15 AM EDT (not 2:15 AM which doesn't exist)
        let springFireComponents = calendar.dateComponents(
            [.hour, .minute],
            from: springNextFire
        )
        XCTAssertEqual(springFireComponents.hour, 3, "Should skip to 3 AM during spring forward")
        XCTAssertEqual(springFireComponents.minute, 15)

        // Test case 2: Fall back (2 AM occurs twice)
        // November 3, 2024 at 1:45 AM EDT
        var fallComponents = DateComponents()
        fallComponents.year = 2024
        fallComponents.month = 11
        fallComponents.day = 3
        fallComponents.hour = 1
        fallComponents.minute = 45
        fallComponents.second = 0
        fallComponents.timeZone = easternTimeZone

        guard let fallDate = calendar.date(from: fallComponents) else {
            XCTFail("Could not create fall DST test date")
            return
        }

        // WHEN: Snoozing for 30 minutes (crosses DST boundary)
        let fallNextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: fallDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds(min: 5 * 60, max: 60 * 60),
            calendar: calendar,
            timeZone: easternTimeZone
        )

        // THEN: Should fire at 2:15 AM (the second occurrence in EST)
        let fallFireComponents = calendar.dateComponents(
            [.hour, .minute],
            from: fallNextFire
        )
        XCTAssertEqual(fallFireComponents.hour, 2, "Should use 2 AM during fall back")
        XCTAssertEqual(fallFireComponents.minute, 15)

        // Verify it's actually 75 minutes later (not 30) due to repeated hour
        let actualInterval = fallNextFire.timeIntervalSince(fallDate)
        XCTAssertGreaterThan(
            actualInterval,
            30 * 60,
            "Fall back should result in longer actual interval"
        )
    }

    // MARK: - Basic Snooze Execution Tests

    func test_snooze_execution_basic() {
        // GIVEN: An alarm and current time
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        let now = Date()
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Snoozing for 10 minutes
        let nextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 10 * 60,
            bounds: bounds
        )

        // THEN: Next fire should be approximately 10 minutes later
        let interval = nextFire.timeIntervalSince(now)
        XCTAssertEqual(
            interval,
            10 * 60,
            accuracy: 1.0,
            "Should fire 10 minutes later"
        )
    }

    func test_snooze_execution_with_clamping() {
        // GIVEN: An alarm and restrictive bounds
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        let now = Date()
        let bounds = SnoozeBounds(min: 15 * 60, max: 30 * 60)

        // WHEN: Requesting snooze below minimum
        let shortSnooze = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 5 * 60, // 5 minutes
            bounds: bounds
        )

        // THEN: Should be clamped to 15 minutes
        let shortInterval = shortSnooze.timeIntervalSince(now)
        XCTAssertEqual(
            shortInterval,
            15 * 60,
            accuracy: 1.0,
            "Should be clamped to minimum"
        )

        // WHEN: Requesting snooze above maximum
        let longSnooze = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 60 * 60, // 60 minutes
            bounds: bounds
        )

        // THEN: Should be clamped to 30 minutes
        let longInterval = longSnooze.timeIntervalSince(now)
        XCTAssertEqual(
            longInterval,
            30 * 60,
            accuracy: 1.0,
            "Should be clamped to maximum"
        )
    }

    // MARK: - Presentation Policy Tests

    func test_presentation_policy_defaults() {
        // GIVEN: Default presentation policy
        let policy = AlarmPresentationPolicy()

        // WHEN: Checking for alarm without snooze configured
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()

        // THEN: Should not show countdown (snooze not configured)
        XCTAssertFalse(
            policy.shouldShowCountdown(for: alarm),
            "Should not show countdown without snooze configuration"
        )

        XCTAssertFalse(
            policy.requiresLiveActivity(for: alarm),
            "Should not require live activity without snooze"
        )
    }

    func test_stop_button_semantics() {
        // GIVEN: Various alarm configurations

        // WHEN: Alarm has challenges
        let withChallenges = AlarmPresentationPolicy.stopButtonSemantics(
            challengesRequired: true
        )

        // THEN: Should require validation
        XCTAssertEqual(
            withChallenges,
            .requiresChallengeValidation,
            "Should require validation when challenges present"
        )

        // WHEN: Alarm has no challenges
        let noChallenges = AlarmPresentationPolicy.stopButtonSemantics(
            challengesRequired: false
        )

        // THEN: Should always be enabled
        XCTAssertEqual(
            noChallenges,
            .alwaysEnabled,
            "Should be always enabled without challenges"
        )
    }

    // MARK: - Next Occurrence Tests

    func test_next_occurrence_for_recurring_alarm() {
        // GIVEN: A recurring weekday alarm (Mon-Fri at 7:00 AM)
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        alarm.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

        // Set alarm time to 7:00 AM
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        components.second = 0
        alarm.time = calendar.date(from: components) ?? Date()

        // WHEN: Checking next occurrence from a Sunday
        var sundayComponents = DateComponents()
        sundayComponents.year = 2024
        sundayComponents.month = 3
        sundayComponents.day = 3 // A Sunday
        sundayComponents.hour = 20
        sundayComponents.minute = 0
        let sunday = calendar.date(from: sundayComponents) ?? Date()

        let nextOccurrence = SnoozeAlarm.nextOccurrence(
            for: alarm,
            after: sunday,
            calendar: calendar,
            timeZone: calendar.timeZone
        )

        // THEN: Should be Monday at 7:00 AM
        if let next = nextOccurrence {
            let nextComponents = calendar.dateComponents(
                [.weekday, .hour, .minute],
                from: next
            )
            XCTAssertEqual(nextComponents.weekday, 2, "Should be Monday (weekday 2)")
            XCTAssertEqual(nextComponents.hour, 7, "Should be at 7 AM")
            XCTAssertEqual(nextComponents.minute, 0, "Should be at 0 minutes")
        } else {
            XCTFail("Should find next occurrence")
        }
    }
}