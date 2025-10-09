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
                case .dismissal(let id):
                    // Legacy stub route - can be removed after migration
                    DismissalFlowView(alarmID: id, onFinish: { router.backToList() })
                case .ringing(let id):
                    RingingView(alarmID: id, container: container)
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
