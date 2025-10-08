//
//  Untitled.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

import Foundation

public struct Alarm: Codable, Equatable, Hashable, Identifiable {
  public let id: UUID
  var time: Date
  var label: String
  var repeatDays: [Weekdays]
  var challengeKind: [Challenges]
  var expectedQR: String?
  var stepThreshold: Int?
  var mathChallenge: MathChallenge?
  var isEnabled: Bool
  var soundId: String     // Stable sound ID for catalog lookup
  var soundName: String?  // Legacy field - kept for backward compatibility
  var volume: Double      // Volume for in-app ringing and previews only (0.0-1.0)

  // MARK: - Coding Keys (CRITICAL for proper encoding/decoding)
  private enum CodingKeys: String, CodingKey {
    case id, time, label, repeatDays, challengeKind
    case expectedQR, stepThreshold, mathChallenge
    case isEnabled, volume
    case soundId    // CRITICAL: Must be in CodingKeys for proper encoding
    case soundName  // Keep for backward compatibility
  }

  // MARK: - Custom Decoder (handles missing soundId from old JSON)
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode all existing fields
    id = try container.decode(UUID.self, forKey: .id)
    time = try container.decode(Date.self, forKey: .time)
    label = try container.decode(String.self, forKey: .label)
    repeatDays = try container.decode([Weekdays].self, forKey: .repeatDays)
    challengeKind = try container.decode([Challenges].self, forKey: .challengeKind)
    expectedQR = try container.decodeIfPresent(String.self, forKey: .expectedQR)
    stepThreshold = try container.decodeIfPresent(Int.self, forKey: .stepThreshold)
    mathChallenge = try container.decodeIfPresent(MathChallenge.self, forKey: .mathChallenge)
    isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    volume = try container.decode(Double.self, forKey: .volume)

    // Handle missing soundId gracefully (for old persisted alarms)
    soundId = try container.decodeIfPresent(String.self, forKey: .soundId) ?? "ringtone1"

    // Keep legacy soundName for backward compatibility
    soundName = try container.decodeIfPresent(String.self, forKey: .soundName)
  }

  // Standard initializer for new alarms
  init(id: UUID, time: Date, label: String, repeatDays: [Weekdays], challengeKind: [Challenges],
       expectedQR: String? = nil, stepThreshold: Int? = nil, mathChallenge: MathChallenge? = nil,
       isEnabled: Bool, soundId: String, soundName: String? = nil, volume: Double) {
    self.id = id
    self.time = time
    self.label = label
    self.repeatDays = repeatDays
    self.challengeKind = challengeKind
    self.expectedQR = expectedQR
    self.stepThreshold = stepThreshold
    self.mathChallenge = mathChallenge
    self.isEnabled = isEnabled
    self.soundId = soundId
    self.soundName = soundName
    self.volume = volume
  }
}

extension Alarm {
  @available(*, unavailable, message: "Use AlarmFactory.makeNewAlarm() instead")
  static var blank: Alarm {
    // This will cause a compile-time error, preventing runtime crashes
    fatalError("Alarm.blank is deprecated - use AlarmFactory.makeNewAlarm() instead")
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
