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

    private let dependencyContainer = DependencyContainer.shared

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
                .environmentObject(dependencyContainer)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func setupNotificationDelegate() {
        // Clean activation via DI container
        dependencyContainer.activateNotificationDelegate()

        // First-launch migration: refresh all alarms to ensure userInfo consistency
        // This cleans up any legacy requests missing userInfo
        Task {
            do {
                let alarms = try await dependencyContainer.persistenceService.loadAlarms()
                await dependencyContainer.notificationService.refreshAll(from: alarms)
                print("App Launch: Refreshed all alarms for userInfo consistency")
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
