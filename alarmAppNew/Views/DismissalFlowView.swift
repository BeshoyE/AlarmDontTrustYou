
import SwiftUI

struct DismissalFlowView: View {
    let alarmID: UUID
    let onFinish: () -> Void
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSceneReady = false

    var body: some View {
        Group {
            if isSceneReady {
                RingingView(alarmID: alarmID, container: container)
                    .onDisappear {
                        onFinish()
                    }
            } else {
                // Loading state while scene becomes ready
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .task {
            await ensureSceneReadiness()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active && !isSceneReady {
                Task {
                    await ensureSceneReadiness()
                }
            }
        }
    }
    
    @MainActor
    private func ensureSceneReadiness() async {
        // Wait for scene to be active
        guard scenePhase == .active else { return }
        
        // Short defer to prevent black screens on cold-start
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        isSceneReady = true
    }
}
