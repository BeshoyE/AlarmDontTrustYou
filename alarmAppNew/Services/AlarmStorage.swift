//
//  AlarmStorage.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/17/25.
//

import Foundation

protocol AlarmStorage {

  func loadAlarms() throws -> [Alarm]
  func saveAlarms(_ alarm:[Alarm]) throws
}


