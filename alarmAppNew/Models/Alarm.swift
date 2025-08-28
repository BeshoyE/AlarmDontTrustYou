//
//  Untitled.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

import Foundation

struct Alarm: Codable, Equatable, Hashable, Identifiable {
  let id: UUID
  var time: Date
  var label: String
  var repeatDays: [Weekdays]
  var challengeKind: [Challenges]
  var expectedQR: String?
  var stepThreshold: Int?
  var mathChallenge: MathChallenge?
  var isEnabled: Bool
}

extension Alarm {
  static var blank: Alarm {
    Alarm(id: UUID(),
          time: Date(),
          label: "blank",
          repeatDays: [],
          challengeKind: [],
          isEnabled: true)
  }

  // Add this computed property for display purposes
  var repeatDaysText: String {
    guard !repeatDays.isEmpty else { return "" }

    // Check for common patterns
    if repeatDays.count == 7 {
      return "Every day"
    } else if Set(repeatDays) == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) {
      return "Weekdays"
    } else if Set(repeatDays) == Set([.saturday, .sunday]) {
      return "Weekends"
    } else {
      // Sort days by their natural week order and return abbreviated names
      let sortedDays = repeatDays.sorted { $0.rawValue < $1.rawValue }
      return sortedDays.map { $0.displayName }.joined(separator: ", ")
    }
  }
}
