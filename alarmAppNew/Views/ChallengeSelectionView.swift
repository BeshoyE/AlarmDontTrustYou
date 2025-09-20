//
//  ChallengeSelectionView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/26/25.
//

import SwiftUI

struct ChallengeSelectionView: View {

  @Binding var draft: Alarm
  @Environment(\.dismiss) private var dismiss
  @State private var showingQRScanner = false

  var body: some View {
    NavigationStack{
      List{
        ForEach(Challenges.allCases,id:\.self){ challenge in
          Button {
            handleChallengeSelection(challenge)
          } label: {
            HStack {
              Label(challenge.displayName, systemImage: challenge.iconName)
                .foregroundColor(.primary)
              Spacer()

              if draft.challengeKind.contains(challenge) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.accentColor)
              }
            }
          }
          .disabled(draft.challengeKind.contains(challenge))

        }
      }
      .navigationTitle("Add Challenge")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .sheet(isPresented: $showingQRScanner) {
      QRScannerView (
        onCancel: {
          showingQRScanner = false
        },
        onScanned: { scannedCode in
          draft.expectedQR = scannedCode
          if !draft.challengeKind.contains(.qr) {
            draft.challengeKind.append(.qr)
          }
          showingQRScanner = false
          dismiss()
        },
        permissionService: DependencyContainer.shared.permissionService
      )
    }

  }

  private func handleChallengeSelection(_ challenge: Challenges) {
    switch challenge {
    case .qr:
      showingQRScanner = true
    default:
      if !draft.challengeKind.contains(challenge) {
        draft.challengeKind.append(challenge)
      }
      dismiss()
    }
  }

}

#Preview {
    ChallengeSelectionView(
        draft: .constant(Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.math],  // Pre-populate with a challenge to see checkmark
            expectedQR: nil,
            isEnabled: true,
            volume: 2.0
        ))
    )
}
