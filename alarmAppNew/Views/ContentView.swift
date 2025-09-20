// alarmAppNew/…/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        switch router.route {
        case .alarmList:
            AlarmsListView()
        case .dismissal(let id):
            // Legacy stub route - can be removed after migration
            DismissalFlowView(alarmID: id, onFinish: { router.backToList() })
        case .ringing(let id):
            RingingView(alarmID: id)
                .interactiveDismissDisabled(true)
        }
    }
}

#Preview {
    ContentView().environmentObject(AppRouter())
}
