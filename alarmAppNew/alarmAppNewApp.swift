//
//  alarmAppNewApp.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//


import SwiftUI
import UserNotifications

@main
struct alarmAppNewApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // OWNED instance - no singleton
    private let dependencyContainer = DependencyContainer()

    init() {
        // CRITICAL: Activate AlarmKit scheduler at app launch (iOS 26+ only)
        setupAlarmKit()

        // Activate observability systems for production-ready logging
        dependencyContainer.activateObservability()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()              // we'll repurpose ContentView as the Root
                .environmentObject(dependencyContainer.appRouter)
                .environment(\.container, dependencyContainer)  // Inject via environment
                // Check for pending intents when app becomes active
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task { @MainActor in
                        dependencyContainer.alarmIntentBridge.checkForPendingIntent()
                    }
                }
                // Route to ringing screen when alarm intent is received
                .onReceive(NotificationCenter.default.publisher(for: .alarmIntentReceived)) { notification in
                    if let intentAlarmId = notification.userInfo?["intentAlarmId"] as? UUID {
                        // For post-migration alarms, intent ID == domain UUID
                        // For pre-migration alarms, we pass intent ID and use fallback in stop()
                        // Since we can't determine which is which here, pass intent ID as both
                        dependencyContainer.appRouter.showRinging(for: intentAlarmId, intentAlarmID: intentAlarmId)
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func setupAlarmKit() {
        // AlarmKit activation and initialization sequence (iOS 26+ only)
        Task {
            do {
                // 1. Activate AlarmKit scheduler (idempotent)
                await dependencyContainer.activateAlarmScheduler()
                print("App Launch: Activated AlarmKit scheduler")

                // 2. ONE-TIME MIGRATION: Reconcile AlarmKit IDs after external mapping removal
                //    This ensures alarms scheduled before the ID mapping fix are re-registered
                //    with their domain UUIDs. Runs once per migration version.
                await dependencyContainer.migrateAlarmKitIDsIfNeeded()
                print("App Launch: Completed AlarmKit ID migration check")

                // 3. Selective reconciliation: sync daemon with domain alarms
                //    Uses daemon as source of truth; only touches mismatched alarms
                let alarms = try await dependencyContainer.persistenceService.loadAlarms()
                await dependencyContainer.alarmScheduler.reconcile(
                    alarms: alarms,
                    skipIfRinging: true
                )
                print("App Launch: Reconciled daemon state")
            } catch {
                print("App Launch: Failed to setup AlarmKit: \(error)")
            }
        }

        print("App Launch: AlarmKit setup initiated")
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active {
            Task {
                // Clean up incomplete alarm runs from previous sessions
                do {
                    try await dependencyContainer.alarmRunStore.cleanupIncompleteRuns()  // NEW: async actor call
                } catch {
                    print("Failed to cleanup incomplete runs: \(error)")
                }

                // Re-register all notifications when app becomes active
                let alarmListVM = dependencyContainer.makeAlarmListViewModel()
                await alarmListVM.refreshAllAlarms()
            }
        }
    }
}
