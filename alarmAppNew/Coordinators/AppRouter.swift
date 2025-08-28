//
//  AppRouter.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/20/25.
//

// alarmAppNew/…/AppRouter.swift
import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    enum Route: Equatable {
        case alarmList
        case dismissal(alarmID: UUID)
    }

    @Published var route: Route = .alarmList

    func showDismissal(for id: UUID) {
        route = .dismissal(alarmID: id)
    }

    func backToList() {
        route = .alarmList
    }
}
