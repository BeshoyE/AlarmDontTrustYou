//
//  DeliveredNotificationsReader.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Protocol adapter for reading delivered notifications (Infrastructure → Domain boundary)
//

import Foundation
import UserNotifications

/// Simplified representation of a delivered notification
/// Domain-friendly model without iOS framework dependencies
public struct DeliveredNotification {
    public let identifier: String
    public let deliveredDate: Date

    public init(identifier: String, deliveredDate: Date) {
        self.identifier = identifier
        self.deliveredDate = deliveredDate
    }
}

/// Protocol for reading delivered notifications
/// Wraps UNUserNotificationCenter.getDeliveredNotifications() behind a testable interface
public protocol DeliveredNotificationsReading {
    func getDeliveredNotifications() async -> [DeliveredNotification]
}

/// Default implementation that wraps UNUserNotificationCenter
public final class UNDeliveredNotificationsReader: DeliveredNotificationsReading {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func getDeliveredNotifications() async -> [DeliveredNotification] {
        let notifications = await center.deliveredNotifications()
        return notifications.map { notification in
            DeliveredNotification(
                identifier: notification.request.identifier,
                deliveredDate: notification.date
            )
        }
    }
}
