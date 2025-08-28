////
////  View+DismissalFlow.swift
////  alarmAppNew
////
////  Created by Beshoy Eskarous on 7/24/25.
////
//
//import SwiftUI
//
//extension View {
//  func dismissalFLow(for alarmID: Binding<UUID?>) -> some View {
//    self.fullScreenCover(item: alarmID) { id in
//      let vm = DismissalFlowViewModel(alarmID: id)
//      DismissalFlowView(viewModel: vm) {
//        alarmID.wrappedValue = nil
//      }
//    }
//  }
//}
