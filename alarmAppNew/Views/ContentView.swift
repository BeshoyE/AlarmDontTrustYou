// alarmAppNew/…/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        switch router.route {
        case .alarmList:
            AlarmsListView()
        case .dismissal(let id):
            // If/when you wire the VM, pass it here:
            // DismissalFlowView(viewModel: .init(alarmID: id), onFinish: { router.backToList() })
            DismissalFlowView(alarmID: id, onFinish: { router.backToList() })
        }
    }
}

#Preview {
    ContentView().environmentObject(AppRouter())
}
