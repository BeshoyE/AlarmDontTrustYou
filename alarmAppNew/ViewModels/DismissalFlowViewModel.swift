//
//  DismissalFlowViewModel.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/22/25.
//

import SwiftUI

class DismissalFlowViewModel: ObservableObject {
  @Published var showQRSheet = false
  @Published var navigateToNextChallenge = false
  private let alarmID: UUID

  init(alarmID: UUID) {
    self.alarmID = alarmID
  }

  func start() {
    showQRSheet = true
  }

  func qrDidComplete() {
    showQRSheet = false
    navigateToNextChallenge = true
  }

}

