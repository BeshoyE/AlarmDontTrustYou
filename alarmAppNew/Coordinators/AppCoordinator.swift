//
//  AppCoordinator.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI


class AppCoordinator: ObservableObject {
  @Published var alarmToDismiss: UUID? = nil

  func showDismissal (for alarmID: UUID) {
    alarmToDismiss = alarmID
  }

  func dismissalCompleted() {    alarmToDismiss = nil
  }
}

