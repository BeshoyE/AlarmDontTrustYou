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
 @State private var isTestingSoundNotification = false
 let onSave: () -> Void

 // Inject container for accessing services
 private let container: DependencyContainer

 init(detailVM: AlarmDetailViewModel, container: DependencyContainer, onSave: @escaping () -> Void) {
     self.detailVM = detailVM
     self.container = container
     self.onSave = onSave
 }

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
       
       Section(header: Text("Sound")) {
         // Sound Picker - Use SoundCatalog for consistency with alarm model
         Picker("Sound", selection: detailVM.soundIdBinding) {
           ForEach(container.soundCatalog.all, id: \.id) { sound in
             Text(sound.name).tag(sound.id)
           }
         }
         .pickerStyle(.menu)
         
         // Preview Button
         Button(action: previewCurrentSound) {
           HStack {
             Image(systemName: "play.circle")
             Text("Preview Sound")
             Spacer()
           }
         }
         .buttonStyle(.plain)
         .foregroundColor(.accentColor)
         
         // Volume Slider
         VStack(alignment: .leading, spacing: 8) {
           Text("In-app ring volume (doesn't affect lock-screen)")
             .font(.caption)
             .foregroundColor(.secondary)
           
           HStack {
             Image(systemName: "speaker.fill")
               .foregroundColor(.secondary)
               .font(.caption)
             
             Slider(value: detailVM.volumeBinding, in: 0.0...1.0, step: 0.1)
             
             Image(systemName: "speaker.wave.3.fill")
               .foregroundColor(.secondary)
               .font(.caption)
           }
           
           Text("Volume: \(Int(detailVM.draft.volume * 100))%")
             .font(.caption2)
             .foregroundColor(.secondary)
         }
         
         // Test Notification Button
         Button(action: testSoundNotification) {
           HStack {
             if isTestingSoundNotification {
               ProgressView()
                 .scaleEffect(0.8)
               Text("Test notification sent...")
             } else {
               Image(systemName: "bell.badge")
               Text("Test Sound Notification")
             }
             Spacer()
           }
         }
         .buttonStyle(.plain)
         .foregroundColor(isTestingSoundNotification ? .secondary : .accentColor)
         .disabled(isTestingSoundNotification)

         // Education banner about ringer vs media volume
         VStack(alignment: .leading, spacing: 8) {
           HStack {
             Image(systemName: "info.circle")
               .foregroundColor(.blue)
             Text("Volume Settings")
               .font(.caption)
               .fontWeight(.medium)
               .foregroundColor(.blue)
           }

           Text(AudioUXPolicy.educationCopy)
             .font(.caption2)
             .foregroundColor(.secondary)
         }
         .padding(.vertical, 4)
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
       ChallengeSelectionView(draft: $detailVM.draft, container: container)
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
             permissionService: container.permissionService
         )
     }
   }
   

 }
  // MARK: - Sound Functions

  private func previewCurrentSound() {
    // TODO: Implement preview using audioEngine
    // AudioService was removed - need to add preview method to AlarmAudioEngineProtocol
    print("Sound preview: \(detailVM.draft.soundName ?? "default") at volume \(detailVM.draft.volume)")
  }

  private func testSoundNotification() {
    Task {
      isTestingSoundNotification = true
      defer {
        Task { @MainActor in
          // Reset after 3 seconds
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          isTestingSoundNotification = false
        }
      }

      do {
        try await container.notificationService.scheduleTestNotification(
          soundName: detailVM.draft.soundName,
          in: 5.0
        )
      } catch {
        print("Failed to schedule test notification: \(error)")
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
