//
//  AlarmFormView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/26/25.
//

import SwiftUI

struct AlarmFormView: View {
 @ObservedObject var detailVM: AlarmDetailViewModel
 @State private var isAddingChallenge = false
 @State private var showQRScanner = false
 let onSave: () -> Void

 var body: some View {
   NavigationStack {
     Form {
       Section(header: Text("Time")) {
         DatePicker(
           "Alarm Time",
           selection: $detailVM.draft.time,
           displayedComponents: .hourAndMinute
         )
       }

       TextField("Label", text: $detailVM.draft.label)

       Section(header: Text("Repeat")) {
         ForEach(Weekdays.allCases, id: \.self) { day in
           Toggle(
             day.displayName,
             isOn: detailVM.repeatBinding(for: day)
           )
         }
       }

       Section(header: Text("Challenges")) {
         if detailVM.draft.challengeKind.isEmpty {
           HStack {
             Text("No challenges Added")
               .foregroundColor(.secondary)
             Spacer()
             Button {
               isAddingChallenge = true
             } label: {
               Label("Add", systemImage: "plus.circle")
             }
           }
         } else {
           ForEach(detailVM.draft.challengeKind, id: \.self) { kind in
             ChallengeRow(
               kind: kind,
               detailViewModel: detailVM,
               onRemove: {
                 detailVM.removeChallenge(kind)
               },
               onConfigureQR: {
                 showQRScanner = true
               }
             )
           }

           Button {
             isAddingChallenge = true
           } label: {
             Label("Add Challenge", systemImage: "plus.circle")
               .foregroundColor(.accentColor)
           }
         }
       }
     }
     .navigationTitle("New Alarm")
     .navigationBarTitleDisplayMode(.inline)
     .toolbar {
       ToolbarItem(placement: .navigationBarTrailing) {
         Button("Save") {
           onSave()
         }
         .disabled(!detailVM.isValid)
       }
       ToolbarItem(placement: .navigationBarLeading) {
         Button("Cancel") {
           // handle cancel
         }
       }
     }
     .navigationDestination(isPresented: $isAddingChallenge) {
       ChallengeSelectionView(draft: $detailVM.draft)
     }
     .sheet(isPresented: $showQRScanner) {
         QRScannerView(
             onCancel: {
                 showQRScanner = false
             },
             onScanned: { scannedCode in
                 detailVM.draft.expectedQR = scannedCode
                 showQRScanner = false
             },
             permissionService: DependencyContainer.shared.permissionService
         )
     }
   }
 }
}

struct ChallengeRow: View {
 let kind: Challenges
 @ObservedObject var detailViewModel: AlarmDetailViewModel
 let onRemove: () -> Void
 let onConfigureQR: () -> Void

 var body: some View {
   VStack(alignment: .leading, spacing: 8) {
     HStack {
       Label(kind.displayName, systemImage: kind.iconName)
         .font(.headline)

       Spacer()

       Button {
         onRemove()
       } label: {
         Image(systemName: "xmark.circle.fill")
           .foregroundColor(.secondary)
       }
       .buttonStyle(.plain)
     }

     if kind == .qr {
       Button {
         onConfigureQR()
       } label: {
         HStack {
           Text("QR Code:")
             .foregroundColor(.primary)
           Spacer()
           if let qrCode = detailViewModel.draft.expectedQR {
             Text(qrCode)
               .lineLimit(1)
               .truncationMode(.middle)
               .foregroundColor(.secondary)
           } else {
             Text("Tap to scan")
               .foregroundColor(.accentColor)
           }
           Image(systemName: "chevron.right")
             .font(.caption)
             .foregroundColor(.secondary)
         }
       }
       .buttonStyle(.plain)
     }
   }
   .padding(.vertical, 4)
 }
}
