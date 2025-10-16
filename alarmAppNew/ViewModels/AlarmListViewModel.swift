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
  @Published var showMediaVolumeWarning = false

  private let storage: PersistenceStore
  private let permissionService: PermissionServiceProtocol
  private let alarmScheduler: AlarmScheduling
  private let refresher: RefreshRequesting
  private let systemVolumeProvider: SystemVolumeProviding
  private let notificationService: AlarmScheduling  // Keep for test methods only

  init(
    storage: PersistenceStore,
    permissionService: PermissionServiceProtocol,
    alarmScheduler: AlarmScheduling,
    refresher: RefreshRequesting,
    systemVolumeProvider: SystemVolumeProviding,
    notificationService: AlarmScheduling  // Keep for test methods
  ) {
    self.storage = storage
    self.permissionService = permissionService
    self.alarmScheduler = alarmScheduler
    self.refresher = refresher
    self.systemVolumeProvider = systemVolumeProvider
    self.notificationService = notificationService

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
    Task {
      do {
        let loadedAlarms = try await storage.loadAlarms()
        await MainActor.run {
          self.alarms = loadedAlarms
          self.errorMessage = nil
        }
      } catch {
        await MainActor.run {
          self.alarms = []
          self.errorMessage = "Could not load alarms"
        }
      }
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

    // Check media volume before enabling alarm
    if !alarm.isEnabled {
      checkMediaVolumeBeforeArming()
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
      try await storage.saveAlarms(alarms)

      // Handle scheduling based on enabled state using unified scheduler
      if !alarm.isEnabled {
        // Cancel alarm when disabling
        await alarmScheduler.cancel(alarmId: alarm.id)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Cancelled (disabled)")
      } else {
        // Schedule alarm when enabling/adding
        // AlarmScheduling.schedule() is always immediate (no separate "immediate" method)
        _ = try await alarmScheduler.schedule(alarm: alarm)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Scheduled")
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
        // Handle specific scheduling errors with appropriate messaging
        if let schedulingError = error as? AlarmSchedulingError {
          switch schedulingError {
          case .systemLimitExceeded:
            // Provide helpful guidance for system limit
            self.errorMessage = "Too many alarms scheduled. Please disable some alarms to add more (iOS limit: 64 notifications)."
          case .permissionDenied:
            self.errorMessage = schedulingError.description
            self.showPermissionBlocking = true
          case .schedulingFailed:
            self.errorMessage = schedulingError.description
          case .invalidConfiguration:
            self.errorMessage = schedulingError.description
          case .notAuthorized:
            self.errorMessage = "AlarmKit permission not granted"
            self.showPermissionBlocking = true
          case .alarmNotFound:
            self.errorMessage = "Alarm not found in system"
          case .ambiguousAlarmState:
            self.errorMessage = "Multiple alarms alerting - cannot determine which to stop"
          case .alreadyHandledBySystem:
            self.errorMessage = "Alarm was already handled by system"
          }
        } else {
          self.errorMessage = "Could not update alarm"
        }
      }
    }
  }
  
  func refreshAllAlarms() async {
    // Use refresher which knows how to use the correct scheduler
    await refresher.requestRefresh(alarms: alarms)
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

  // MARK: - Volume Warning

  /// Checks media volume and shows warning if below threshold
  private func checkMediaVolumeBeforeArming() {
    let currentVolume = systemVolumeProvider.currentMediaVolume()

    if currentVolume < AudioUXPolicy.lowMediaVolumeThreshold {
      showMediaVolumeWarning = true
    } else {
      showMediaVolumeWarning = false
    }
  }

  /// Schedules a one-off test alarm to verify lock-screen sound volume
  func testLockScreen() {
    Task {
      do {
        try await notificationService.scheduleOneOffTestAlarm(
          leadTime: AudioUXPolicy.testLeadSeconds
        )
        print("✅ Lock-screen test alarm scheduled (fires in \(Int(AudioUXPolicy.testLeadSeconds))s)")
      } catch {
        errorMessage = "Failed to schedule test alarm: \(error.localizedDescription)"
      }
    }
  }
}
