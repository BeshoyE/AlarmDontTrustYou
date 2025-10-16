//
//  AppRouter.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/20/25.
//

// alarmAppNew/…/AppRouter.swift
import SwiftUI

protocol AppRouting {
    func showRinging(for id: UUID, intentAlarmID: UUID?)
    func backToList()
}

@MainActor
final class AppRouter: ObservableObject, AppRouting {
    enum Route: Equatable {
        case alarmList
        case ringing(alarmID: UUID, intentAlarmID: UUID? = nil)   // Enforced ringing route for MVP1
    }

    @Published var route: Route = .alarmList

    // Single-instance guard: track if dismissal flow is active
    private var activeDismissalAlarmId: UUID?

    // Store the intent alarm ID separately (could be pre-migration ID)
    private var currentIntentAlarmId: UUID?

    func showRinging(for id: UUID, intentAlarmID: UUID? = nil) {
        // Strengthen double-route guard
        if activeDismissalAlarmId == id, case .ringing(let current, _) = route, current == id {
            return // already showing this alarm
        }

        print("AppRouter: Showing ringing for alarm: \(id), intentAlarmID: \(intentAlarmID?.uuidString.prefix(8) ?? "nil")")
        activeDismissalAlarmId = id
        currentIntentAlarmId = intentAlarmID
        route = .ringing(alarmID: id, intentAlarmID: intentAlarmID)
        print("AppRouter: Route set to ringing, activeDismissalAlarmId: \(activeDismissalAlarmId?.uuidString.prefix(8) ?? "nil")")
    }

    func backToList() {
        // Clear active dismissal state when returning to list
        activeDismissalAlarmId = nil
        currentIntentAlarmId = nil
        route = .alarmList
    }
    
    // Getter for testing and debugging
    var isInDismissalFlow: Bool {
        return activeDismissalAlarmId != nil
    }

    var currentDismissalAlarmId: UUID? {
        return activeDismissalAlarmId
    }

    var currentIntentAlarmIdValue: UUID? {
        return currentIntentAlarmId
    }
}
