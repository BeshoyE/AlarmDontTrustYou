//
//  DependencyContainer.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/28/25.
//
// MARK: - Privacy Settings Required
// Add these to Info.plist or Project Settings:
// NSCameraUsageDescription: "This app needs camera access to scan QR codes for alarm dismissal. Scanning a QR code is required to turn off your alarm and proves you are awake."
// NSUserNotificationUsageDescription: "This app needs notification permission to deliver reliable alarm notifications that will wake you up at the scheduled time."

import Foundation

@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    // MARK: - Services
    let permissionService: PermissionServiceProtocol
    let persistenceService: AlarmStorage
    let notificationService: NotificationScheduling
    
    private init() {
        self.permissionService = PermissionService()
        self.persistenceService = PersistenceService()
        self.notificationService = NotificationService(permissionService: permissionService)
    }
    
    // MARK: - ViewModels
    func makeAlarmListViewModel() -> AlarmListViewModel {
        return AlarmListViewModel(
            storage: persistenceService, 
            permissionService: permissionService,
            notificationService: notificationService
        )
    }
    
    func makeAlarmDetailViewModel(alarm: Alarm? = nil) -> AlarmDetailViewModel {
        let targetAlarm = alarm ?? Alarm.blank
        return AlarmDetailViewModel(alarm: targetAlarm, isNew: alarm == nil)
    }
    
    func makeDismissalFlowViewModel(alarmID: UUID) -> DismissalFlowViewModel {
        return DismissalFlowViewModel(alarmID: alarmID, permissionService: permissionService)
    }
}