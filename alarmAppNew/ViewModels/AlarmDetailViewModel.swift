//
//  AlarmDetailViewModel.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/22/25.
//

import SwiftUI

class AlarmDetailViewModel:ObservableObject, Identifiable {
  let id = UUID()
  @Published var draft: Alarm
  let isNewAlarm: Bool

  
  init(alarm: Alarm, isNew: Bool = false) {
    self.draft = alarm
    self.isNewAlarm = isNew
  }

  var isValid: Bool {
    //qr challenge is either not selected or qr var is not empty
    let qrOK = !draft.challengeKind.contains(.qr) || (draft.expectedQR?.isEmpty == false)
    let soundOK = draft.soundName != nil && !draft.soundName!.isEmpty
    let volumeOK = draft.volume >= 0.0 && draft.volume <= 1.0
    return qrOK && soundOK && volumeOK && !draft.label.isEmpty && draft.time > Date()
  }

  func commitChanges() -> Alarm {
    return draft
  }

  func repeatBinding(for day: Weekdays) -> Binding<Bool> {
    Binding<Bool> (
      get: {self.draft.repeatDays.contains(day) },
      set: { isOn in
        if isOn {
          if !self.draft.repeatDays.contains(day){
            self.draft.repeatDays.append(day)
          }
        } else {
          self.draft.repeatDays.removeAll { $0 == day }
        }
      }
    )
  }

  func removeChallenge(_ kind: Challenges) {
    draft.challengeKind.removeAll{$0 == kind}
    if kind == .qr {
      draft.expectedQR = nil
    }
  }
  
  // MARK: - Sound Management
  
  func updateSound(_ soundName: String) {
    draft.soundName = soundName
  }
  
  func updateVolume(_ volume: Double) {
    draft.volume = max(0.0, min(1.0, volume))
  }
  
  var volumeBinding: Binding<Double> {
    Binding<Double>(
      get: { self.draft.volume },
      set: { self.updateVolume($0) }
    )
  }
  
  var soundNameBinding: Binding<String> {
    Binding<String>(
      get: { self.draft.soundName ?? "default" },
      set: { self.updateSound($0) }
    )
  }
}
