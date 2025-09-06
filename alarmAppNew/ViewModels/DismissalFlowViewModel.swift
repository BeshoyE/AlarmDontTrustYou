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
  private let permissionService: PermissionServiceProtocol

  init(alarmID: UUID, permissionService: PermissionServiceProtocol) {
    self.alarmID = alarmID
    self.permissionService = permissionService
  }

  func start() {
    showQRSheet = true
  }

  func qrDidComplete() {
    showQRSheet = false
    navigateToNextChallenge = true
  }

}

