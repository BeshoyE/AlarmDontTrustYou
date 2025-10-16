//
//  AlarmPresentationBuilder.swift
//  alarmAppNew
//
//  Builder for AlarmKit presentation and schedule configurations.
//  Separates presentation logic from scheduling implementation.
//

import Foundation
import AlarmKit
import SwiftUI

// Type disambiguation: separate domain model from AlarmKit framework types
typealias DomainAlarm = Alarm        // Our domain model

@available(iOS 26.0, *)
typealias AKAlarm = AlarmKit.Alarm   // AlarmKit framework type

/// Protocol for building AlarmKit presentation configurations
protocol AlarmPresentationBuilding {
    /// Build schedule configuration from alarm
    @available(iOS 26.0, *)
    func buildSchedule(from alarm: DomainAlarm) throws -> AKAlarm.Schedule

    /// Build presentation configuration for alarm
    @available(iOS 26.0, *)
    func buildPresentation(for alarm: DomainAlarm) throws -> AlarmAttributes<EmptyMetadata>
}

/// Empty metadata struct conforming to AlarmMetadata
@available(iOS 26.0, *)
struct EmptyMetadata: AlarmMetadata {
    static var defaultValue: EmptyMetadata { EmptyMetadata() }
}

/// Default implementation of presentation builder
struct AlarmPresentationBuilder: AlarmPresentationBuilding {

    enum BuilderError: Error {
        case invalidTime
        case invalidConfiguration
    }

    /// Map domain Weekdays enum to Locale.Weekday (locale-safe)
    @available(iOS 26.0, *)
    private func mapWeekdays(_ days: [Weekdays]) -> [Locale.Weekday] {
        days.map { weekday in
            switch weekday {
            case .sunday: return .sunday
            case .monday: return .monday
            case .tuesday: return .tuesday
            case .wednesday: return .wednesday
            case .thursday: return .thursday
            case .friday: return .friday
            case .saturday: return .saturday
            }
        }
    }

    @available(iOS 26.0, *)
    func buildSchedule(from alarm: DomainAlarm) throws -> AKAlarm.Schedule {
        // Extract time components from alarm
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: alarm.time)

        guard let hour = components.hour, let minute = components.minute else {
            throw BuilderError.invalidTime
        }

        // Create schedule - .fixed() for one-time, .relative() for recurring
        if alarm.repeatDays.isEmpty {
            // One-time alarm at specific date/time
            return .fixed(alarm.time)
        } else {
            // Recurring alarm on specific weekdays
            let time = AKAlarm.Schedule.Relative.Time(hour: hour, minute: minute)
            let recurrence = AKAlarm.Schedule.Relative.Recurrence.weekly(mapWeekdays(alarm.repeatDays))
            let relative = AKAlarm.Schedule.Relative(time: time, repeats: recurrence)
            return .relative(relative)
        }
    }

    @available(iOS 26.0, *)
    func buildPresentation(for alarm: DomainAlarm) throws -> AlarmAttributes<EmptyMetadata> {
        // Wrap title in LocalizedStringResource as required by AlarmKit
        let title = LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? "Alarm" : alarm.label)

        // Create alert presentation with constructed buttons using proper 3-parameter constructor
        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Stop"),
            textColor: .primary,
            systemImageName: "stop.circle"
        )
        let openAppButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Open App"),
            textColor: .accentColor,
            systemImageName: "arrow.up.right.circle"
        )

        let alertContent = AlarmPresentation.Alert(
            title: title,
            stopButton: stopButton,
            secondaryButton: openAppButton,
            secondaryButtonBehavior: .custom
        )

        // Build full presentation (alert only for now - no countdown in alert phase)
        let presentation = AlarmPresentation(alert: alertContent)

        // Create attributes with app's theme color
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: EmptyMetadata.defaultValue,
            tintColor: .blue
        )

        return attributes
    }
}
