
import SwiftUI

struct DismissalFlowView: View {
    let alarmID: UUID
    let onFinish: () -> Void

    // If you want to use the VM immediately:
    // @StateObject private var vm: DismissalFlowViewModel
    // init(alarmID: UUID, onFinish: @escaping () -> Void) {
    //     self.alarmID = alarmID
    //     self.onFinish = onFinish
    //     _vm = StateObject(wrappedValue: DismissalFlowViewModel(alarmID: alarmID))
    // }

    var body: some View {
        // Temporary stub UI — call onFinish() when the flow is completed.
        VStack(spacing: 16) {
            Text("Dismissal Flow for \(alarmID.uuidString.prefix(6))…")
            Button("Complete (stub)") { onFinish() }
        }
        .padding()
    }
}
