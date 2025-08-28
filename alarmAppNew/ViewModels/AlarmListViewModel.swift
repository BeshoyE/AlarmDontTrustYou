//
//  AlarmListViewModel.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/21/25.
//
import Foundation
import SwiftUI

@MainActor
class AlarmListViewModel: ObservableObject {
  @Published var errorMessage: String?
  @Published var alarms: [Alarm] = []
  private let storage: AlarmStorage

  init(storage: AlarmStorage = PersistenceService()) {
    self.storage = storage
    fetchAlarms()
  }

  func fetchAlarms() {
    do {
      alarms = try storage.loadAlarms()
      errorMessage = nil
    } catch {
      alarms = []
      errorMessage = "Could not load alarms"
    }
  }

  func add (_ alarm: Alarm) {
    alarms.append(alarm)
    sync(alarm)
  }

  func toggle(_ alarm:Alarm) {
    guard let thisAlarm = alarms.firstIndex(where: {$0.id == alarm.id}) else { return }
      alarms[thisAlarm].isEnabled.toggle()
      sync(alarms[thisAlarm])

  }



  func update(_ alarm: Alarm) {
    guard let thisAlarm = alarms.firstIndex(where: {$0.id == alarm.id}) else { return }
      alarms[thisAlarm] = alarm
      sync(alarm)

  }

  func delete(_ alarm: Alarm) {

    alarms.removeAll{ $0.id == alarm.id}
    sync(alarm)

  }

  private func sync (_ alarm: Alarm) {
    do {
      try storage.saveAlarms(alarms)
      if let idx = alarms.firstIndex(where: {$0.id == alarm.id}),
      alarm.isEnabled {
        NotificationService.shared.cancelAlarm(alarm)
        NotificationService.shared.scheduleAlarm(alarm)
      } else {
        NotificationService.shared.cancelAlarm(alarm)
      }
      errorMessage = nil
    } catch {
      errorMessage = "Could not update alarm"
    }
  }
}
