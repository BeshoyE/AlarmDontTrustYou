//
//  NotificationService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/7/25.
//

import UserNotifications
import SwiftUI


class NotificationService: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationService()
  private let center = UNUserNotificationCenter.current()

  private override init() {
    super.init()
    center.delegate = self
    center.requestAuthorization(options: [.alert,.sound,.badge]) { _, _ in }
  }


  func scheduleAlarm(_ alarm: Alarm) {

    //create the content

    let content = UNMutableNotificationContent()
    content.title = alarm.label
    content.sound = .default

    if alarm.repeatDays.isEmpty {
      let dateComps = Calendar.current.dateComponents([.hour,.minute], from: alarm.time)
      let trigger = UNCalendarNotificationTrigger(dateMatching: dateComps, repeats: false)
      let req = UNNotificationRequest(identifier: alarm.id.uuidString,
                                      content: content,
                                      trigger: trigger)
      center.add(req)
    } else {
      for day in alarm.repeatDays {
        // make the trigger
        var dateComps = Calendar.current.dateComponents([.hour,.minute], from: alarm.time)
        dateComps.weekday = day.rawValue
        let id = "\(alarm.id.uuidString)-weekday-\(day.rawValue)"
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComps,
                                                    repeats: true)
        //put the request together
        let request = UNNotificationRequest(identifier: id,
                                            content: content,
                                            trigger: trigger)
        //add the request
        center.add(request)
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

}


extension Notification.Name {
  static let alarmDidFire = Notification.Name("alarmDidFire")
}



