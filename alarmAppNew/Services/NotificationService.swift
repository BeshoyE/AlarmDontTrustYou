//
//  NotificationService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/7/25.
//

import UserNotifications
import SwiftUI

// MARK: - Notification Scheduling Protocol
protocol NotificationScheduling {
    func scheduleAlarm(_ alarm: Alarm) async throws
    func cancelAlarm(_ alarm: Alarm)
    func refreshAll(from alarms: [Alarm]) async
    func pendingAlarmIds() async -> [UUID]
}

class NotificationService: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private let permissionService: PermissionServiceProtocol
  
  init(permissionService: PermissionServiceProtocol) {
    self.permissionService = permissionService
    super.init()
    center.delegate = self
  }


  func scheduleAlarm(_ alarm: Alarm) async throws {
    // Check permissions before scheduling
    let permissionDetails = await permissionService.checkNotificationPermission()
    
    guard permissionDetails.authorizationStatus == .authorized else {
      throw NotificationError.permissionDenied
    }
    
    // Warn if notifications are authorized but muted
    if permissionDetails.isAuthorizedButMuted {
      // Log warning - sound is disabled
      print("Warning: Notifications authorized but sound is disabled")
    }
    
    // Create the content
    let content = UNMutableNotificationContent()
    content.title = alarm.label
    content.sound = .default
    content.categoryIdentifier = "ALARM_CATEGORY"
    
    // Add action for returning to dismissal flow
    content.userInfo = ["alarmId": alarm.id.uuidString]
    
    if alarm.repeatDays.isEmpty {
      let dateComps = Calendar.current.dateComponents([.hour,.minute], from: alarm.time)
      let trigger = UNCalendarNotificationTrigger(dateMatching: dateComps, repeats: false)
      let req = UNNotificationRequest(identifier: alarm.id.uuidString,
                                      content: content,
                                      trigger: trigger)
      try await center.add(req)
    } else {
      for day in alarm.repeatDays {
        var dateComps = Calendar.current.dateComponents([.hour,.minute], from: alarm.time)
        dateComps.weekday = day.rawValue
        let id = "\(alarm.id.uuidString)-weekday-\(day.rawValue)"
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComps,
                                                    repeats: true)
        let request = UNNotificationRequest(identifier: id,
                                            content: content,
                                            trigger: trigger)
        try await center.add(request)
      }
    }
  }

  //delegateMethod

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    //pull out the id as a string with an if let

    let fullID = response.notification.request.identifier
    let baseID = fullID.components(separatedBy: "-weekday-").first ?? fullID
    guard let uuid = UUID(uuidString: baseID) else {
      completionHandler()
      return
    }
      NotificationCenter.default.post(name: .alarmDidFire, object: uuid)
      completionHandler()
  }

  func cancelAlarm(_ alarm: Alarm) {
    let perDayIDs = alarm.repeatDays.map { "\(alarm.id.uuidString)-weekday-\($0.rawValue)"}
    let allIDs = perDayIDs + [alarm.id.uuidString]
    center.removePendingNotificationRequests(withIdentifiers: allIDs)
  }
  
  func refreshAll(from alarms: [Alarm]) async {
    // Cancel all pending notifications
    center.removeAllPendingNotificationRequests()
    
    // Re-schedule all enabled alarms
    for alarm in alarms where alarm.isEnabled {
      do {
        try await scheduleAlarm(alarm)
      } catch {
        print("Failed to schedule alarm \(alarm.id): \(error)")
      }
    }
  }
  
  func pendingAlarmIds() async -> [UUID] {
    let requests = await center.pendingNotificationRequests()
    return requests.compactMap { request in
      let baseID = request.identifier.components(separatedBy: "-weekday-").first ?? request.identifier
      return UUID(uuidString: baseID)
    }
  }

}


// MARK: - Notification Errors
enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission is required to schedule alarms"
        case .schedulingFailed:
            return "Failed to schedule notification"
        }
    }
}

extension Notification.Name {
  static let alarmDidFire = Notification.Name("alarmDidFire")
}



