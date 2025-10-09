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
        // CRITICAL: Ensure notification delegate is set immediately at app launch
        // This guarantees the delegate is live before any notifications can fire
        setupNotificationDelegate()

        // Activate observability systems for production-ready logging
        dependencyContainer.activateObservability()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()              // we'll repurpose ContentView as the Root
                .environmentObject(dependencyContainer.appRouter)
                .environment(\.container, dependencyContainer)  // Inject via environment
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func setupNotificationDelegate() {
        // Clean activation via DI container
        dependencyContainer.activateNotificationDelegate()

        // Startup sequence: delegate → refresh → cleanup
        // Ensures correct initialization order per architecture requirements
        Task {
            do {
                // 1. Load and refresh all alarms for userInfo consistency
                let alarms = try await dependencyContainer.persistenceService.loadAlarms()
                await dependencyContainer.refreshCoordinator.requestRefresh(alarms: alarms)
                print("App Launch: Refreshed all alarms for userInfo consistency (via coordinator)")

                // 2. Clean up stale delivered notifications from previous sessions
                await dependencyContainer.notificationService.cleanupStaleDeliveredNotifications()
                print("App Launch: Cleaned up stale notifications")
            } catch {
                print("App Launch: Failed to refresh alarms: \(error)")
            }
        }

        print("App Launch: Notification delegate and categories set during app initialization")
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active {
            Task {
                // Clean up incomplete alarm runs from previous sessions
                do {
                    try dependencyContainer.persistenceService.cleanupIncompleteRuns()
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
