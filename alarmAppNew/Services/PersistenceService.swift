//
//  PersistenceService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/10/25.
//  Converted to actor for thread-safe persistence per CLAUDE.md §3
//

import Foundation


actor PersistenceService: PersistenceStore {
  private let userDefaultsKey = "savedAlarms"
  private let defaults: UserDefaults
  private let soundCatalog: SoundCatalogProviding
  private var hasPerformedRepair = false
  private var isRepairing = false

  init(defaults: UserDefaults = .standard, soundCatalog: SoundCatalogProviding? = nil) {
    self.defaults = defaults
    self.soundCatalog = soundCatalog ?? SoundCatalog(validateFiles: false)
  }

  func loadAlarms() throws -> [Alarm] {
    print("📂 PersistenceService.loadAlarms: Loading alarms from UserDefaults")
    guard let data = defaults.data(forKey: userDefaultsKey) else {
      print("📂 PersistenceService.loadAlarms: No data found, returning empty array")
      return []
    }

    print("📂 PersistenceService.loadAlarms: Found \(data.count) bytes")
    var alarms = try JSONDecoder().decode([Alarm].self, from: data)
    print("📂 PersistenceService.loadAlarms: Decoded \(alarms.count) alarms")

    // Perform one-time repair for invalid soundIds
    if !hasPerformedRepair {
      var needsRepair = false

      for i in alarms.indices {
        if soundCatalog.info(for: alarms[i].soundId) == nil {
          // Log the validation fix
          print("🔧 PersistenceService: Resetting invalid soundId '\(alarms[i].soundId)' to default '\(soundCatalog.defaultSoundId)' for alarm \(alarms[i].id)")

          // Direct soundId mutation approach
          alarms[i] = Alarm(
            id: alarms[i].id,
            time: alarms[i].time,
            label: alarms[i].label,
            repeatDays: alarms[i].repeatDays,
            challengeKind: alarms[i].challengeKind,
            expectedQR: alarms[i].expectedQR,
            stepThreshold: alarms[i].stepThreshold,
            mathChallenge: alarms[i].mathChallenge,
            isEnabled: alarms[i].isEnabled,
            soundId: soundCatalog.defaultSoundId,
            soundName: alarms[i].soundName,
            volume: alarms[i].volume,
            externalAlarmId: alarms[i].externalAlarmId
          )
          needsRepair = true
        }
      }

      if needsRepair && !isRepairing {
        isRepairing = true
        defer { isRepairing = false }
        try saveAlarms(alarms)
      }

      hasPerformedRepair = true
    }

    return alarms
  }
  
  func saveAlarms(_ alarms: [Alarm]) throws {
    print("💾 PersistenceService.saveAlarms: Saving \(alarms.count) alarms")
    let data = try JSONEncoder().encode(alarms)
    defaults.set(data, forKey: userDefaultsKey)
    defaults.synchronize() // Force immediate write
    print("💾 PersistenceService.saveAlarms: Successfully saved \(alarms.count) alarms (\(data.count) bytes)")
  }


}
