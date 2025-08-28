//
//  QRScannerView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI
import CodeScanner

struct QRScannerView: View {
  @Environment(\.dismiss) private var dismiss
  let onCancel: () -> Void
  let onScanned: (String) -> Void

  var body: some View {

    NavigationStack {
      CodeScannerView(
        codeTypes: [.qr],
        completion: handleScan
      )
      .navigationTitle("Scan QR")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
            dismiss()
          }
        }
      }

    }
  }

  //doesn't handle error right now
  private func handleScan(result: Result<ScanResult, ScanError>) {
    switch result {
    case .success(let scan):
      onScanned(scan.string)
      dismiss()
    case .failure:
      onCancel()
      dismiss()
    }
  }
}



