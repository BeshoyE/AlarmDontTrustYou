//
//  Weekdays.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

enum Weekdays: Int, Codable, CaseIterable, Equatable {

  case sunday = 1
  case monday = 2
  case tuesday = 3
  case wednesday = 4
  case thursday = 5
  case friday = 6
  case saturday = 7

  var displayName: String {
    switch self {
    case .sunday: return "Sun"
    case .monday: return "Mon"
    case .tuesday: return "Tues"
    case .wednesday: return "Wed"
    case .thursday: return "Thurs"
    case .friday: return "Friday"
    case .saturday: return "Saturday"
    }
  }
}
