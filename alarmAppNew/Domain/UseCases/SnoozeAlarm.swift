//
//  SnoozeAlarm.swift
//  alarmAppNew
//
//  Pure domain use case for calculating snooze times.
//  This handles DST transitions and timezone changes correctly.
//

import Foundation

/// Use case for snoozing an alarm.
///
/// This calculates the next fire time for a snoozed alarm, handling:
/// - Clamping duration to valid bounds
/// - DST transitions (fall back / spring forward)
/// - Timezone changes
/// - Local wall-clock time preservation
public struct SnoozeAlarm {

    /// Calculate the next fire time for a snoozed alarm.
    ///
    /// - Parameters:
    ///   - alarm: The alarm being snoozed
    ///   - now: The current time
    ///   - requestedSnooze: The requested snooze duration in seconds
    ///   - bounds: The valid snooze duration bounds
    ///   - calendar: Calendar to use for calculations (defaults to current)
    ///   - timeZone: TimeZone to use (defaults to current)
    /// - Returns: The next fire time for the alarm
    public static func execute(
        alarm: Alarm,
        now: Date,
        requestedSnooze: TimeInterval,
        bounds: SnoozeBounds,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Date {
        // Step 1: Clamp the snooze duration to valid bounds
        let clampedDuration = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedSnooze,
            bounds: bounds
        )

        // Step 2: Calculate next fire time using local components to handle DST
        var adjustedCalendar = calendar
        adjustedCalendar.timeZone = timeZone

        // Get current time components
        let currentComponents = adjustedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )

        // Add snooze duration
        let nextFireDate = now.addingTimeInterval(clampedDuration)

        // Get components of next fire time
        let nextComponents = adjustedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: nextFireDate
        )

        // Step 3: Handle DST transitions
        // If we're crossing a DST boundary, we need to ensure the alarm
        // fires at the intended local time
        if let reconstructedDate = adjustedCalendar.date(from: nextComponents) {
            // Check if the reconstructed date differs significantly from simple addition
            // This indicates a DST transition occurred
            let difference = abs(reconstructedDate.timeIntervalSince(nextFireDate))

            // If difference is more than a few seconds, we crossed DST
            if difference > 10 {
                // For DST transitions, prefer the local wall-clock time
                // This ensures alarm fires at the "expected" local time
                return handleDSTTransition(
                    originalDate: nextFireDate,
                    components: nextComponents,
                    calendar: adjustedCalendar
                )
            }

            return reconstructedDate
        }

        // Fallback to simple time addition if component reconstruction fails
        return nextFireDate
    }

    /// Handle DST transitions by ensuring alarm fires at intended local time.
    private static func handleDSTTransition(
        originalDate: Date,
        components: DateComponents,
        calendar: Calendar
    ) -> Date {
        // During spring forward: 2:30 AM becomes 3:30 AM
        // During fall back: 2:30 AM occurs twice

        // Try to create date from components
        guard let date = calendar.date(from: components) else {
            // If components are invalid (e.g., in spring forward gap),
            // find next valid time
            var adjustedComponents = components

            // Try adding an hour if we're in a gap
            if let hour = adjustedComponents.hour {
                adjustedComponents.hour = hour + 1
                if let adjustedDate = calendar.date(from: adjustedComponents) {
                    return adjustedDate
                }
            }

            // Fallback to original
            return originalDate
        }

        // For fall back, we might get the "first" 2:30 AM when we want the "second"
        // Check if we need to disambiguate
        let isDSTActive = calendar.timeZone.isDaylightSavingTime(for: originalDate)
        let willBeDSTActive = calendar.timeZone.isDaylightSavingTime(for: date)

        // If DST status changed, we crossed a boundary
        if isDSTActive != willBeDSTActive {
            // For fall back: prefer the later occurrence
            // For spring forward: already handled above
            if isDSTActive && !willBeDSTActive {
                // Fall back case: add DST offset to get "second" occurrence
                return date.addingTimeInterval(3600) // Add 1 hour
            }
        }

        return date
    }

    /// Calculate next fire time for a recurring alarm on a specific day.
    ///
    /// This is used when an alarm needs to fire on its next scheduled day,
    /// properly handling DST and timezone changes.
    public static func nextOccurrence(
        for alarm: Alarm,
        after date: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Date? {
        var adjustedCalendar = calendar
        adjustedCalendar.timeZone = timeZone

        // Get alarm time components
        let alarmComponents = adjustedCalendar.dateComponents(
            [.hour, .minute],
            from: alarm.time
        )

        guard let alarmHour = alarmComponents.hour,
              let alarmMinute = alarmComponents.minute else {
            return nil
        }

        // Start from tomorrow to find next occurrence
        guard let tomorrow = adjustedCalendar.date(byAdding: .day, value: 1, to: date) else {
            return nil
        }

        // Check up to 8 days ahead (covers all weekdays)
        for dayOffset in 0..<8 {
            guard let checkDate = adjustedCalendar.date(
                byAdding: .day,
                value: dayOffset,
                to: tomorrow
            ) else { continue }

            // Get weekday for this date
            let weekdayComponent = adjustedCalendar.component(.weekday, from: checkDate)

            // Check if alarm is scheduled for this weekday
            if alarm.repeatDays.isEmpty ||
               alarm.repeatDays.contains(where: { $0.calendarWeekday == weekdayComponent }) {
                // Create date with alarm time on this day
                var components = adjustedCalendar.dateComponents(
                    [.year, .month, .day],
                    from: checkDate
                )
                components.hour = alarmHour
                components.minute = alarmMinute
                components.second = 0

                if let fireDate = adjustedCalendar.date(from: components) {
                    return fireDate
                }
            }
        }

        return nil
    }
}

// MARK: - Helpers

private extension Weekdays {
    /// Convert to Calendar.Component weekday (1=Sunday, 7=Saturday)
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}