//
//  AlarmSchedulerFactory.swift
//  alarmAppNew
//
//  Factory for creating AlarmKit scheduler (iOS 26+ only).
//  Uses explicit dependency injection, not the whole container.
//

import Foundation

/// Factory for creating the AlarmKit scheduler implementation
@MainActor
enum AlarmSchedulerFactory {

    /// Create the AlarmKit scheduler (iOS 26+ only)
    /// - Parameters:
    ///   - presentationBuilder: Builder for AlarmKit presentation configs
    /// - Returns: AlarmKitScheduler instance
    /// - Note: Uses domain UUIDs directly as AlarmKit IDs - no external mapping needed
    @available(iOS 26.0, *)
    static func make(
        presentationBuilder: AlarmPresentationBuilding
    ) -> AlarmScheduling {
        return AlarmKitScheduler(
            presentationBuilder: presentationBuilder
        )
    }
}