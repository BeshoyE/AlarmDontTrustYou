//
//  AlarmListViewModel.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/21/25.
//
import Foundation
import SwiftUI

@MainActor
class AlarmListViewModel: ObservableObject {
  @Published var errorMessage: String?
  @Published var alarms: [Alarm] = []
  @Published var notificationPermissionDetails: NotificationPermissionDetails?
  @Published var showPermissionBlocking = false
  
  private let storage: AlarmStorage
  private let permissionService: PermissionServiceProtocol
  private let notificationService: NotificationScheduling
  private let refresher: RefreshRequesting

  init(
    storage: AlarmStorage,
    permissionService: PermissionServiceProtocol,
    notificationService: NotificationScheduling,
    refresher: RefreshRequesting
  ) {
    self.storage = storage
    self.permissionService = permissionService
    self.notificationService = notificationService
    self.refresher = refresher

    fetchAlarms()
    checkNotificationPermissions()
  }

  func refreshPermission() {
      Task {
          let details = await permissionService.checkNotificationPermission()
          self.notificationPermissionDetails = details
      }
  }


  func fetchAlarms() {
    do {
      alarms = try storage.loadAlarms()
      errorMessage = nil
    } catch {
      alarms = []
      errorMessage = "Could not load alarms"
    }
  }
  
  func checkNotificationPermissions() {
    Task {
      let details = await permissionService.checkNotificationPermission()
      await MainActor.run {
        self.notificationPermissionDetails = details
      }
    }
  }

  func add (_ alarm: Alarm) {
    alarms.append(alarm)
    Task {
      await sync(alarm)
    }
  }

  func toggle(_ alarm:Alarm) {
    guard let thisAlarm = alarms.firstIndex(where: {$0.id == alarm.id}) else { return }
    
    // Data model guardrail: Don't allow enabling alarms without expectedQR (QR-only MVP)
    if !alarm.isEnabled && alarm.expectedQR == nil {
      errorMessage = "Cannot enable alarm: QR code required for dismissal"
      return
    }
    
    alarms[thisAlarm].isEnabled.toggle()
    Task {
      await sync(alarms[thisAlarm])
    }
  }



  func update(_ alarm: Alarm) {
    guard let thisAlarm = alarms.firstIndex(where: {$0.id == alarm.id}) else { return }
    alarms[thisAlarm] = alarm
    Task {
      await sync(alarm)
    }
  }

  func delete(_ alarm: Alarm) {
    alarms.removeAll{ $0.id == alarm.id}
    Task {
      await sync(alarm)
    }
  }

  private func sync(_ alarm: Alarm) async {
    do {
      try storage.saveAlarms(alarms)

      // Handle scheduling based on enabled state
      if !alarm.isEnabled {
        // Cancel notifications when disabling
        await notificationService.cancelAlarm(alarm)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Cancelled (disabled)")
      } else {
        // CRITICAL: Use immediate scheduling path for enables/adds
        // This ensures scheduling completes even if app backgrounds
        try await notificationService.scheduleAlarmImmediately(alarm)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Scheduled immediately")
      }

      // Still trigger refresh for other alarms (non-blocking, best-effort)
      // This handles any other alarms that might need reconciliation
      Task.detached { [weak self] in
        guard let self = self else { return }
        await self.refresher.requestRefresh(alarms: self.alarms)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Background refresh triggered")
      }

      await MainActor.run {
        self.errorMessage = nil
        self.checkNotificationPermissions() // Refresh permission status
      }
    } catch {
      await MainActor.run {
        // Handle specific notification errors with appropriate messaging
        if let notificationError = error as? NotificationError {
          switch notificationError {
          case .systemLimitExceeded:
            // Provide helpful guidance for system limit
            self.errorMessage = "Too many alarms scheduled. Please disable some alarms to add more (iOS limit: 64 notifications)."
          case .permissionDenied:
            self.errorMessage = notificationError.localizedDescription
            self.showPermissionBlocking = true
          case .schedulingFailed:
            self.errorMessage = notificationError.localizedDescription
          case .invalidConfiguration:
            self.errorMessage = notificationError.localizedDescription
          }
        } else {
          self.errorMessage = "Could not update alarm"
        }
      }
    }
  }
  
  func refreshAllAlarms() async {
    await notificationService.refreshAll(from: alarms)
    checkNotificationPermissions()
  }
  
  func handlePermissionGranted() {
    showPermissionBlocking = false
    checkNotificationPermissions()
    
    // Re-sync all enabled alarms
    Task {
      await refreshAllAlarms()
    }
  }

  func ensureNotificationPermissionIfNeeded() {
      Task {
          let details = await permissionService.checkNotificationPermission()
          switch details.authorizationStatus {
          case .notDetermined:
              // show your blocker (or directly request)
              self.showPermissionBlocking = true
          case .denied:
              // keep inline warning; allow Open Settings
              break
          case .authorized:
              break
          }
      }
  }


}
