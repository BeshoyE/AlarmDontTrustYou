//
//  PersistenceService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/10/25.
//

import Foundation


struct PersistenceService: AlarmStorage {
  private let userDefaultsKey = "savedAlarms"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }


  func loadAlarms() throws -> [Alarm] {
    guard let data = defaults.data(forKey: userDefaultsKey) else {
      return []
    }
    return try JSONDecoder().decode([Alarm].self, from: data)

  }
  
  func saveAlarms(_ alarms: [Alarm]) throws {
    let data = try JSONEncoder().encode(alarms)
    defaults.set(data, forKey: userDefaultsKey)
  }


}
