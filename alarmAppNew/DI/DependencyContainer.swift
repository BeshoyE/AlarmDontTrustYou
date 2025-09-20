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
import UserNotifications

@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()

    // MARK: - Services
    let permissionService: PermissionServiceProtocol
    let persistenceService: AlarmStorage
    private let appStateProvider: AppStateProviding
    private let appLifecycleTracker: AppLifecycleTracking
    private let notificationServiceConcrete: NotificationService  // Strong concrete retention
    let qrScanningService: QRScanning
    let audioService: AudioServiceProtocol
    let appRouter: AppRouter
    let reliabilityLogger: ReliabilityLogging

    // Public protocol exposure
    var notificationService: NotificationScheduling { notificationServiceConcrete }

    private var didActivateNotifications = false

    private init() {
        self.permissionService = PermissionService()
        self.persistenceService = PersistenceService()
        self.reliabilityLogger = LocalReliabilityLogger()
        self.appStateProvider = AppStateProvider()
        self.appLifecycleTracker = AppLifecycleTracker()
        self.appRouter = AppRouter()
        self.notificationServiceConcrete = NotificationService(
            permissionService: permissionService,
            appStateProvider: appStateProvider,
            reliabilityLogger: reliabilityLogger,
            appRouter: appRouter,
            persistenceService: persistenceService
        )
        self.qrScanningService = QRScanningService(permissionService: permissionService)
        self.audioService = AudioService()
    }

    // MARK: - Activation

    @MainActor
    func activateNotificationDelegate() {
        guard !didActivateNotifications else { return }

        // Start lifecycle tracking first
        appLifecycleTracker.startTracking()

        // Set up notification delegate and categories
        UNUserNotificationCenter.current().delegate = notificationServiceConcrete
        notificationServiceConcrete.ensureNotificationCategoriesRegistered()

        didActivateNotifications = true
        print("🔄 DependencyContainer: Activated notification delegate and lifecycle tracking")
    }

    /// Activate observability systems (logging, metrics, etc.)
    /// Call this once at app start - idempotent and separate from notifications
    func activateObservability() {
        // Activate reliability logger with proper file protection for lock screen access
        if let logger = reliabilityLogger as? LocalReliabilityLogger {
            logger.activate()
        }
        print("🔄 DependencyContainer: Activated observability systems")
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
    
    func makeDismissalFlowViewModel() -> DismissalFlowViewModel {
        return DismissalFlowViewModel(
            qrScanning: qrScanningService,
            notificationService: notificationService,
            alarmStorage: persistenceService,
            clock: SystemClock(),
            appRouter: appRouter,
            permissionService: permissionService,
            reliabilityLogger: reliabilityLogger,
            audioService: audioService
        )
    }
}
