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
    return qrOK && !draft.label.isEmpty && draft.time > Date()
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
}
