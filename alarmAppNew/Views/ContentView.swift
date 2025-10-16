// alarmAppNew/…/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        // Unwrap container - should always be present from app root
        guard let container = container else {
            return AnyView(Text("Configuration error: Container not injected")
                .foregroundColor(.red))
        }

        return AnyView(
            Group {
                switch router.route {
                case .alarmList:
                    AlarmsListView(container: container)
                case .ringing(let id, let intentAlarmID):
                    RingingView(alarmID: id, intentAlarmID: intentAlarmID, container: container)
                        .environmentObject(container)  // Inject for child views (ScanningContent, FailedContent)
                        .interactiveDismissDisabled(true)
                }
            }
        )
    }
}

#Preview {
    let container = DependencyContainer()
    return ContentView()
        .environmentObject(AppRouter())
        .environment(\.container, container)
}
