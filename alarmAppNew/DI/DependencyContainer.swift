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
import UIKit

@MainActor
class DependencyContainer: ObservableObject {
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
    private let soundEngineConcrete: AlarmSoundEngine
    let settingsServiceConcrete: SettingsService

    // MARK: - New Sound System Services
    private let soundCatalogConcrete: SoundCatalog
    private let alarmFactoryConcrete: DefaultAlarmFactory

    // MARK: - Notification Chaining Services
    private let chainSettingsProviderConcrete: DefaultChainSettingsProvider
    private let notificationIndexConcrete: NotificationIndex
    private let chainPolicyConcrete: ChainPolicy
    private let globalLimitGuardConcrete: GlobalLimitGuard
    private let chainedNotificationSchedulerConcrete: ChainedNotificationScheduler
    private let dismissedRegistryConcrete: DismissedRegistry
    private let refreshCoordinatorConcrete: RefreshCoordinator
    private let activeAlarmPolicyConcrete: ActiveAlarmPolicyProvider
    private let deliveredNotificationsReaderConcrete: DeliveredNotificationsReading
    private let activeAlarmDetectorConcrete: ActiveAlarmDetector
    private let systemVolumeProviderConcrete: SystemVolumeProviding

    // Public protocol exposure
    var notificationService: NotificationScheduling { notificationServiceConcrete }
    var refreshCoordinator: RefreshCoordinator { refreshCoordinatorConcrete }
    var audioEngine: AlarmAudioEngineProtocol { soundEngineConcrete }
    var settingsService: SettingsServiceProtocol { settingsServiceConcrete }
    var soundCatalog: SoundCatalogProviding { soundCatalogConcrete }
    var alarmFactory: AlarmFactory { alarmFactoryConcrete }
    var chainedNotificationScheduler: ChainedNotificationScheduling { chainedNotificationSchedulerConcrete }
    var chainSettingsProvider: ChainSettingsProviding { chainSettingsProviderConcrete }
    var activeAlarmDetector: ActiveAlarmDetector { activeAlarmDetectorConcrete }
    var systemVolumeProvider: SystemVolumeProviding { systemVolumeProviderConcrete }

    private var didActivateNotifications = false

    init() {
        // CRITICAL INITIALIZATION ORDER: Prevent dependency cycles

        // 1. Create SoundCatalog first (no dependencies)
        self.soundCatalogConcrete = SoundCatalog()

        // 2. Create basic services
        self.permissionService = PermissionService()
        self.reliabilityLogger = LocalReliabilityLogger()
        self.appStateProvider = AppStateProvider()
        self.appLifecycleTracker = AppLifecycleTracker()
        self.appRouter = AppRouter()

        // 3. Create PersistenceService (will need sound catalog for repairs in future)
        self.persistenceService = PersistenceService()

        // 4. Create AlarmFactory with sound catalog
        self.alarmFactoryConcrete = DefaultAlarmFactory(catalog: soundCatalogConcrete)

        // 5. Create notification chaining services
        self.chainSettingsProviderConcrete = DefaultChainSettingsProvider()
        let chainSettings = chainSettingsProviderConcrete.chainSettings()

        // Validate settings during initialization (fail fast)
        let validationResult = chainSettingsProviderConcrete.validateSettings(chainSettings)
        assert(validationResult.isValid, "Invalid chain settings: \(validationResult.errorReasons.joined(separator: ", "))")

        self.notificationIndexConcrete = NotificationIndex()
        self.chainPolicyConcrete = ChainPolicy(settings: chainSettings)
        self.globalLimitGuardConcrete = GlobalLimitGuard()
        self.dismissedRegistryConcrete = DismissedRegistry()
        self.activeAlarmPolicyConcrete = ActiveAlarmPolicyProvider(chainPolicy: chainPolicyConcrete)
        self.chainedNotificationSchedulerConcrete = ChainedNotificationScheduler(
            soundCatalog: soundCatalogConcrete,
            notificationIndex: notificationIndexConcrete,
            chainPolicy: chainPolicyConcrete,
            globalLimitGuard: globalLimitGuardConcrete
        )

        // 6. Create audio and settings services (needed by NotificationService)
        self.soundEngineConcrete = AlarmSoundEngine.shared
        self.settingsServiceConcrete = SettingsService(audioEngine: soundEngineConcrete)
        soundEngineConcrete.setReliabilityModeProvider(settingsServiceConcrete)

        // 7. Create remaining services (now with all dependencies available)
        self.notificationServiceConcrete = NotificationService(
            permissionService: permissionService,
            appStateProvider: appStateProvider,
            reliabilityLogger: reliabilityLogger,
            appRouter: appRouter,
            persistenceService: persistenceService,
            chainedScheduler: chainedNotificationSchedulerConcrete,
            settingsService: settingsServiceConcrete,
            audioEngine: soundEngineConcrete,
            dismissedRegistry: dismissedRegistryConcrete,
            chainSettingsProvider: chainSettingsProviderConcrete,
            activeAlarmPolicy: activeAlarmPolicyConcrete,
            lifecycle: appLifecycleTracker
        )
        self.qrScanningService = QRScanningService(permissionService: permissionService)
        self.audioService = AudioService()

        // 8. Create RefreshCoordinator to coalesce refresh requests
        self.refreshCoordinatorConcrete = RefreshCoordinator(notificationService: notificationServiceConcrete)

        // 9. Create ActiveAlarmDetector for auto-routing to dismissal
        self.deliveredNotificationsReaderConcrete = UNDeliveredNotificationsReader()
        self.activeAlarmDetectorConcrete = ActiveAlarmDetector(
            deliveredNotificationsReader: deliveredNotificationsReaderConcrete,
            activeAlarmPolicy: activeAlarmPolicyConcrete,
            dismissedRegistry: dismissedRegistryConcrete,
            alarmStorage: persistenceService
        )

        // 10. Create SystemVolumeProvider (no dependencies)
        self.systemVolumeProviderConcrete = SystemVolumeProvider()

        // 11. Set up policy provider after all services are initialized
        soundEngineConcrete.setPolicyProvider { [weak self] in
            self?.settingsServiceConcrete.audioPolicy ?? AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
        }
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

        // Add foreground cleanup observer for stale chains
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                guard let self = self else { return }

                // Gate cleanup: only run if scheduling is not in progress
                let isSchedulingActive = await self.refreshCoordinatorConcrete.isSchedulingActive()
                if !isSchedulingActive {
                    await self.chainedNotificationSchedulerConcrete.cleanupStaleChains()
                    print("🧹 Ran stale chain cleanup (scheduling was idle)")
                } else {
                    print("⏳ Skipped stale chain cleanup (scheduling in progress)")
                }
            }
        }

        didActivateNotifications = true
        print("🔄 DependencyContainer: Activated notification delegate, lifecycle tracking, and stale chain cleanup")
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
            notificationService: notificationService,
            refresher: refreshCoordinatorConcrete,
            systemVolumeProvider: systemVolumeProviderConcrete
        )
    }
    
    func makeAlarmDetailViewModel(alarm: Alarm? = nil) -> AlarmDetailViewModel {
        let targetAlarm = alarm ?? alarmFactory.makeNewAlarm()
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
            audioService: audioService,
            audioEngine: audioEngine,
            reliabilityModeProvider: settingsService,
            dismissedRegistry: dismissedRegistryConcrete,
            settingsService: settingsService
        )
    }
}
