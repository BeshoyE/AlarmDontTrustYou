//
//  AppRouter.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/20/25.
//

// alarmAppNew/…/AppRouter.swift
import SwiftUI

protocol AppRouting {
    func showDismissal(for id: UUID)
    func showRinging(for id: UUID)
    func backToList()
}

@MainActor
final class AppRouter: ObservableObject, AppRouting {
    enum Route: Equatable {
        case alarmList
        case dismissal(alarmID: UUID) // Legacy stub route - can be removed after migration
        case ringing(alarmID: UUID)   // New enforced ringing route for MVP1
    }

    @Published var route: Route = .alarmList
    
    // Single-instance guard: track if dismissal flow is active
    private var activeDismissalAlarmId: UUID?

    func showDismissal(for id: UUID) {
        // Single-instance guard: ignore if already in dismissal flow
        if case .dismissal = route, activeDismissalAlarmId != nil {
            print("AppRouter: Ignoring dismissal request for \(id) - already in dismissal flow for \(activeDismissalAlarmId!)")
            return
        }
        
        activeDismissalAlarmId = id
        route = .dismissal(alarmID: id)
    }
    
    func showRinging(for id: UUID) {
        // Strengthen double-route guard
        if activeDismissalAlarmId == id, case .ringing(let current) = route, current == id {
            return // already showing this alarm
        }
        
        print("AppRouter: Showing ringing for alarm: \(id)")
        activeDismissalAlarmId = id
        route = .ringing(alarmID: id)
        print("AppRouter: Route set to ringing, activeDismissalAlarmId: \(activeDismissalAlarmId?.uuidString.prefix(8) ?? "nil")")
    }

    func backToList() {
        // Clear active dismissal state when returning to list
        activeDismissalAlarmId = nil
        route = .alarmList
    }
    
    // Getter for testing and debugging
    var isInDismissalFlow: Bool {
        return activeDismissalAlarmId != nil
    }
    
    var currentDismissalAlarmId: UUID? {
        return activeDismissalAlarmId
    }
}
