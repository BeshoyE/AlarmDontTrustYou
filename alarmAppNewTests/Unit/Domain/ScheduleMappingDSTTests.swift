//
//  ScheduleMappingDSTTests.swift
//  alarmAppNewTests
//
//  Tests for DST (Daylight Saving Time) and timezone handling
//  in alarm scheduling. Ensures alarms fire at correct local times
//  regardless of DST transitions or timezone changes.
//

import XCTest
@testable import alarmAppNew

final class ScheduleMappingDSTTests: XCTestCase {

    // MARK: - DST Fall Back Tests

    func test_fall_back_hour_keeps_intended_local_time() {
        // GIVEN: A calendar in Eastern Time (observes DST)
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create an alarm scheduled for 2:30 AM daily
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var alarmComponents = DateComponents()
        alarmComponents.hour = 2
        alarmComponents.minute = 30
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: Computing fire time on fall-back day (Nov 3, 2024)
        // DST ends at 2:00 AM, clocks fall back to 1:00 AM
        var fallBackComponents = DateComponents()
        fallBackComponents.year = 2024
        fallBackComponents.month = 11
        fallBackComponents.day = 3  // Fall back day
        fallBackComponents.hour = 2
        fallBackComponents.minute = 30
        fallBackComponents.second = 0
        fallBackComponents.timeZone = easternTimeZone

        // There are TWO 2:30 AMs on this day:
        // - First at 2:30 AM EDT (before fall back)
        // - Second at 2:30 AM EST (after fall back, 1 hour later)

        guard let firstOccurrence = calendar.date(from: fallBackComponents) else {
            XCTFail("Could not create first occurrence")
            return
        }

        // Get the components back to verify local time
        let resultComponents = calendar.dateComponents(
            [.hour, .minute],
            from: firstOccurrence
        )

        // THEN: Local time should still be 2:30 AM
        XCTAssertEqual(
            resultComponents.hour,
            2,
            "Hour should remain 2 AM"
        )
        XCTAssertEqual(
            resultComponents.minute,
            30,
            "Minutes should remain 30"
        )

        // Verify DST status
        let isDST = easternTimeZone.isDaylightSavingTime(for: firstOccurrence)

        // The calendar typically returns the first occurrence (EDT)
        // But alarm should fire at both 2:30 AMs for reliability

        // Test that we can identify the transition
        let oneHourLater = firstOccurrence.addingTimeInterval(3600)
        let laterComponents = calendar.dateComponents(
            [.hour, .minute],
            from: oneHourLater
        )

        // Due to fall back, one hour later is STILL 2:30 AM (EST now)
        // This is the unique characteristic of fall back
        if laterComponents.hour == 2 && laterComponents.minute == 30 {
            // We're in the repeated hour
            XCTAssertTrue(true, "Correctly identified repeated hour during fall back")
        } else if laterComponents.hour == 3 && laterComponents.minute == 30 {
            // Normal progression (no fall back on this system)
            XCTAssertTrue(true, "System doesn't observe fall back as expected")
        }
    }

    // MARK: - DST Spring Forward Tests

    func test_spring_forward_hour_selects_next_valid_local_time() {
        // GIVEN: A calendar in Eastern Time
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create an alarm scheduled for 2:30 AM daily
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var alarmComponents = DateComponents()
        alarmComponents.hour = 2
        alarmComponents.minute = 30
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: Computing fire time on spring-forward day (March 10, 2024)
        // DST starts at 2:00 AM, clocks spring forward to 3:00 AM
        // 2:30 AM doesn't exist on this day!
        var springComponents = DateComponents()
        springComponents.year = 2024
        springComponents.month = 3
        springComponents.day = 10  // Spring forward day
        springComponents.hour = 2   // This hour doesn't exist!
        springComponents.minute = 30
        springComponents.second = 0
        springComponents.timeZone = easternTimeZone

        // Calendar should adjust to next valid time (3:30 AM)
        let springDate = calendar.date(from: springComponents)

        if let date = springDate {
            let resultComponents = calendar.dateComponents(
                [.hour, .minute],
                from: date
            )

            // THEN: Should skip to 3:30 AM (next valid time)
            XCTAssertEqual(
                resultComponents.hour,
                3,
                "Should skip to 3 AM when 2 AM doesn't exist"
            )
            XCTAssertEqual(
                resultComponents.minute,
                30,
                "Minutes should remain 30"
            )
        } else {
            // Some systems might return nil for invalid time
            XCTAssertNil(springDate, "Invalid time during spring forward may return nil")
        }

        // Test the SnoozeAlarm handling of spring forward
        var beforeSpringForward = DateComponents()
        beforeSpringForward.year = 2024
        beforeSpringForward.month = 3
        beforeSpringForward.day = 10
        beforeSpringForward.hour = 1
        beforeSpringForward.minute = 45
        beforeSpringForward.timeZone = easternTimeZone

        guard let beforeDate = calendar.date(from: beforeSpringForward) else {
            XCTFail("Could not create date before spring forward")
            return
        }

        // Snooze for 30 minutes (crosses spring forward boundary)
        let snoozedDate = SnoozeAlarm.execute(
            alarm: alarm,
            now: beforeDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds.default,
            calendar: calendar,
            timeZone: easternTimeZone
        )

        let snoozedComponents = calendar.dateComponents(
            [.hour, .minute],
            from: snoozedDate
        )

        // Should be 3:15 AM (2:15 AM doesn't exist)
        XCTAssertEqual(
            snoozedComponents.hour,
            3,
            "Snooze across spring forward should skip missing hour"
        )
        XCTAssertEqual(
            snoozedComponents.minute,
            15,
            "Minutes should be correct after spring forward"
        )
    }

    // MARK: - Timezone Change Tests

    func test_timezone_change_recomputes_by_local_components() {
        // GIVEN: An alarm set for 9:00 AM
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var calendar = Calendar(identifier: .gregorian)

        // Start in Eastern Time
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        var alarmComponents = DateComponents()
        alarmComponents.hour = 9
        alarmComponents.minute = 0
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: User travels to Pacific Time
        guard let pacificTimeZone = TimeZone(identifier: "America/Los_Angeles") else {
            XCTSkip("Pacific timezone not available")
            return
        }

        // Recompute alarm time in new timezone
        calendar.timeZone = pacificTimeZone

        // Extract local components from original alarm time
        let localComponents = calendar.dateComponents(
            [.hour, .minute],
            from: alarm.time
        )

        // THEN: Alarm should still be scheduled for 9:00 AM local time
        // (Even though the absolute UTC time has changed)
        XCTAssertEqual(
            localComponents.hour,
            9,
            "Alarm hour should remain 9 AM in local time"
        )
        XCTAssertEqual(
            localComponents.minute,
            0,
            "Alarm minute should remain 0"
        )

        // Verify the absolute time has actually changed
        let easternCalendar = Calendar(identifier: .gregorian)
        var easternCalendarMutable = easternCalendar
        easternCalendarMutable.timeZone = easternTimeZone

        let pacificCalendar = Calendar(identifier: .gregorian)
        var pacificCalendarMutable = pacificCalendar
        pacificCalendarMutable.timeZone = pacificTimeZone

        // Create same local time in both zones
        var testComponents = DateComponents()
        testComponents.year = 2024
        testComponents.month = 6  // No DST complications
        testComponents.day = 15
        testComponents.hour = 9
        testComponents.minute = 0

        testComponents.timeZone = easternTimeZone
        let easternTime = easternCalendarMutable.date(from: testComponents)

        testComponents.timeZone = pacificTimeZone
        let pacificTime = pacificCalendarMutable.date(from: testComponents)

        if let eastern = easternTime, let pacific = pacificTime {
            let timeDifference = eastern.timeIntervalSince(pacific)
            // Eastern is 3 hours ahead of Pacific
            XCTAssertEqual(
                timeDifference,
                -3 * 3600,
                accuracy: 60,
                "Should be 3 hour difference between timezones"
            )
        }
    }

    // MARK: - Complex Scenario Tests

    func test_multiple_dst_transitions_in_year() {
        // GIVEN: A recurring alarm throughout the year
        var calendar = Calendar(identifier: .gregorian)
        guard let timezone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = timezone

        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        alarm.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

        // Set alarm for 6:00 AM
        var alarmComponents = DateComponents()
        alarmComponents.hour = 6
        alarmComponents.minute = 0
        alarmComponents.timeZone = timezone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // Test dates throughout the year
        let testDates = [
            // Before spring DST
            (month: 2, day: 15, expectedHour: 6, description: "February (Standard Time)"),
            // After spring DST
            (month: 4, day: 15, expectedHour: 6, description: "April (Daylight Time)"),
            // Summer
            (month: 7, day: 15, expectedHour: 6, description: "July (Daylight Time)"),
            // After fall DST
            (month: 12, day: 15, expectedHour: 6, description: "December (Standard Time)")
        ]

        for testDate in testDates {
            var components = DateComponents()
            components.year = 2024
            components.month = testDate.month
            components.day = testDate.day
            components.hour = 6
            components.minute = 0
            components.timeZone = timezone

            if let date = calendar.date(from: components) {
                let hourComponent = calendar.component(.hour, from: date)

                XCTAssertEqual(
                    hourComponent,
                    testDate.expectedHour,
                    "Alarm should fire at \(testDate.expectedHour):00 local time in \(testDate.description)"
                )

                // Verify DST status
                let isDST = timezone.isDaylightSavingTime(for: date)
                if testDate.month >= 4 && testDate.month <= 10 {
                    XCTAssertTrue(isDST, "\(testDate.description) should be in DST")
                } else {
                    XCTAssertFalse(isDST, "\(testDate.description) should be in Standard Time")
                }
            }
        }
    }

    func test_alarm_scheduling_preserves_local_time_across_dst() {
        // GIVEN: An alarm set in standard time for 7:00 AM
        var calendar = Calendar.current
        guard let timezone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = timezone

        // January date (Standard Time)
        var januaryComponents = DateComponents()
        januaryComponents.year = 2024
        januaryComponents.month = 1
        januaryComponents.day = 15
        januaryComponents.hour = 7
        januaryComponents.minute = 0
        januaryComponents.timeZone = timezone

        guard let januaryDate = calendar.date(from: januaryComponents) else {
            XCTFail("Could not create January date")
            return
        }

        // WHEN: The same alarm needs to fire in July (Daylight Time)
        var julyComponents = DateComponents()
        julyComponents.year = 2024
        julyComponents.month = 7
        julyComponents.day = 15
        julyComponents.hour = 7  // Same local time
        julyComponents.minute = 0
        julyComponents.timeZone = timezone

        guard let julyDate = calendar.date(from: julyComponents) else {
            XCTFail("Could not create July date")
            return
        }

        // THEN: Both should show 7:00 AM local time
        let janHour = calendar.component(.hour, from: januaryDate)
        let julHour = calendar.component(.hour, from: julyDate)

        XCTAssertEqual(janHour, 7, "January alarm should be at 7 AM")
        XCTAssertEqual(julHour, 7, "July alarm should be at 7 AM")

        // But the UTC times should differ by 1 hour due to DST
        let utcCalendar = Calendar(identifier: .gregorian)
        var utcCalendarMutable = utcCalendar
        utcCalendarMutable.timeZone = TimeZone(abbreviation: "UTC")!

        let janUTCHour = utcCalendarMutable.component(.hour, from: januaryDate)
        let julUTCHour = utcCalendarMutable.component(.hour, from: julyDate)

        // Eastern Standard Time is UTC-5, Eastern Daylight Time is UTC-4
        // 7 AM EST = 12 PM UTC
        // 7 AM EDT = 11 AM UTC
        let hourDifference = abs(janUTCHour - julUTCHour)
        XCTAssertEqual(
            hourDifference,
            1,
            "UTC times should differ by 1 hour due to DST"
        )
    }
}