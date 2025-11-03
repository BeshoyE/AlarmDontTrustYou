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
    let persistenceService: PersistenceStore
    let alarmRunStore: AlarmRunStore
    let qrScanningService: QRScanning
    let appRouter: AppRouter
    let reliabilityLogger: ReliabilityLogging
    private let soundEngineConcrete: AlarmSoundEngine
    let settingsServiceConcrete: SettingsService
    let alarmIntentBridge: AlarmIntentBridge
    let alarmScheduler: AlarmScheduling
    private let idleTimerControllerConcrete: UIApplicationIdleTimerController
    private let shareProviderConcrete: ShareProviding

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
    var refreshCoordinator: RefreshCoordinator { refreshCoordinatorConcrete }
    var audioEngine: AlarmAudioEngineProtocol { soundEngineConcrete }
    var settingsService: SettingsServiceProtocol { settingsServiceConcrete }
    var soundCatalog: SoundCatalogProviding { soundCatalogConcrete }
    var alarmFactory: AlarmFactory { alarmFactoryConcrete }
    var chainedNotificationScheduler: ChainedNotificationScheduling { chainedNotificationSchedulerConcrete }
    var chainSettingsProvider: ChainSettingsProviding { chainSettingsProviderConcrete }
    var activeAlarmDetector: ActiveAlarmDetector { activeAlarmDetectorConcrete }
    var systemVolumeProvider: SystemVolumeProviding { systemVolumeProviderConcrete }
    var notificationService: AlarmScheduling { alarmScheduler }  // Expose alarmScheduler as notificationService for legacy code

    init() {
        // CRITICAL INITIALIZATION ORDER: Prevent dependency cycles

        // 1. Create SoundCatalog first (no dependencies)
        self.soundCatalogConcrete = SoundCatalog()

        // 2. Create basic services
        self.permissionService = PermissionService()
        self.reliabilityLogger = LocalReliabilityLogger()
        self.appRouter = AppRouter()

        // 3. Create PersistenceService (will need sound catalog for repairs in future)
        self.persistenceService = PersistenceService()

        // 3.5. Create AlarmRunStore (actor-based, thread-safe)
        self.alarmRunStore = AlarmRunStore()

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
        self.qrScanningService = QRScanningService(permissionService: permissionService)
        self.idleTimerControllerConcrete = UIApplicationIdleTimerController()
        self.shareProviderConcrete = SystemShareProvider()

        // 8. Create AlarmScheduler using factory pattern (iOS 26+ only)
        // Note: Uses domain UUIDs directly - no external ID mapping needed
        let presentationBuilder = AlarmPresentationBuilder()
        if #available(iOS 26.0, *) {
            self.alarmScheduler = AlarmSchedulerFactory.make(
                presentationBuilder: presentationBuilder
            )
        } else {
            fatalError("iOS 26+ required for AlarmKit")
        }

        // 9. Create RefreshCoordinator to coalesce refresh requests
        self.refreshCoordinatorConcrete = RefreshCoordinator(notificationService: alarmScheduler)

        // 10. Create ActiveAlarmDetector for auto-routing to dismissal
        self.deliveredNotificationsReaderConcrete = UNDeliveredNotificationsReader()
        self.activeAlarmDetectorConcrete = ActiveAlarmDetector(
            deliveredNotificationsReader: deliveredNotificationsReaderConcrete,
            activeAlarmPolicy: activeAlarmPolicyConcrete,
            dismissedRegistry: dismissedRegistryConcrete,
            alarmStorage: persistenceService
        )

        // 11. Create SystemVolumeProvider (no dependencies)
        self.systemVolumeProviderConcrete = SystemVolumeProvider()

        // 12. Create AlarmIntentBridge (no dependencies, no OS work in init)
        self.alarmIntentBridge = AlarmIntentBridge()

        // 13. Set up policy provider after all services are initialized
        soundEngineConcrete.setPolicyProvider { [weak self] in
            self?.settingsServiceConcrete.audioPolicy ?? AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
        }
    }

    // MARK: - Activation

    /// Activate observability systems (logging, metrics, etc.)
    /// Call this once at app start - idempotent and separate from notifications
    func activateObservability() {
        // Activate reliability logger with proper file protection for lock screen access
        if let logger = reliabilityLogger as? LocalReliabilityLogger {
            logger.activate()
        }
        print("🔄 DependencyContainer: Activated observability systems")
    }

    /// Activate the alarm scheduler if it's AlarmKit-based
    /// Call this after the container is initialized - idempotent
    @MainActor
    func activateAlarmScheduler() async {
        if #available(iOS 26.0, *) {
            if let kitScheduler = alarmScheduler as? AlarmKitScheduler {
                await kitScheduler.activate()
                print("🔄 DependencyContainer: Activated AlarmKit scheduler")
            }
        }
    }

    /// One-time migration: reconcile AlarmKit IDs after removing external ID mapping
    /// Ensures all alarms use domain UUIDs directly
    @MainActor
    func migrateAlarmKitIDsIfNeeded() async {
        if #available(iOS 26.0, *) {
            if let kitScheduler = alarmScheduler as? AlarmKitScheduler {
                let persisted = (try? await persistenceService.loadAlarms()) ?? []
                await kitScheduler.reconcileAlarmsAfterMigration(persisted: persisted)

                // Clean up externalAlarmId from persisted alarms
                let cleaned = persisted.map { alarm -> Alarm in
                    var mutableAlarm = alarm
                    mutableAlarm.externalAlarmId = nil
                    return mutableAlarm
                }

                if cleaned != persisted {
                    do {
                        try await persistenceService.saveAlarms(cleaned)
                        print("🔄 DependencyContainer: Cleared legacy externalAlarmId fields")
                    } catch {
                        print("⚠️ DependencyContainer: Failed to save cleaned alarms: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - ViewModels
    func makeAlarmListViewModel() -> AlarmListViewModel {
        return AlarmListViewModel(
            storage: persistenceService,
            permissionService: permissionService,
            alarmScheduler: alarmScheduler,
            refresher: refreshCoordinatorConcrete,
            systemVolumeProvider: systemVolumeProviderConcrete,
            notificationService: alarmScheduler  // AlarmScheduler conforms to NotificationScheduling
        )
    }
    
    func makeAlarmDetailViewModel(alarm: Alarm? = nil) -> AlarmDetailViewModel {
        let targetAlarm = alarm ?? alarmFactory.makeNewAlarm()
        return AlarmDetailViewModel(alarm: targetAlarm, isNew: alarm == nil)
    }
    
    func makeDismissalFlowViewModel(intentAlarmID: UUID? = nil) -> DismissalFlowViewModel {
        return DismissalFlowViewModel(
            qrScanning: qrScanningService,
            notificationService: alarmScheduler,  // AlarmScheduler conforms to NotificationScheduling
            alarmStorage: persistenceService,
            clock: SystemClock(),
            appRouter: appRouter,
            permissionService: permissionService,
            reliabilityLogger: reliabilityLogger,
            audioEngine: audioEngine,
            reliabilityModeProvider: settingsService,
            dismissedRegistry: dismissedRegistryConcrete,
            settingsService: settingsService,
            alarmScheduler: alarmScheduler,
            alarmRunStore: alarmRunStore,  // NEW: Inject actor-based run store
            idleTimerController: idleTimerControllerConcrete,  // NEW: UIKit isolation
            stopAllowed: StopAlarmAllowed.self,
            snoozeComputer: SnoozeAlarm.self,
            intentAlarmId: intentAlarmID  // Pass the intent-provided alarm ID
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            reliabilityLogger: reliabilityLogger,
            shareProvider: shareProviderConcrete
        )
    }
}
