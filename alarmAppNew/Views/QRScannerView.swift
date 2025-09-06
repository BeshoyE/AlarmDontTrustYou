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
  let permissionService: PermissionServiceProtocol
  
  @State private var cameraPermissionStatus: PermissionStatus = .notDetermined
  @State private var showPermissionBlocking = false

  var body: some View {
    NavigationStack {
      Group {
        if cameraPermissionStatus == .authorized {
          CodeScannerView(
            codeTypes: [.qr],
            completion: handleScan
          )
        } else if cameraPermissionStatus == .denied {
          CameraPermissionBlockingView(
            permissionService: permissionService,
            onPermissionGranted: {
              cameraPermissionStatus = .authorized
            },
            onCancel: {
              onCancel()
              dismiss()
            }
          )
        } else {
          ProgressView("Checking camera permission...")
        }
      }
      .navigationTitle("Scan QR")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if cameraPermissionStatus == .authorized {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              onCancel()
              dismiss()
            }
          }
        }
      }
      .onAppear {
        checkCameraPermission()
      }
    }
  }
  
  private func checkCameraPermission() {
    let currentStatus = permissionService.checkCameraPermission()
    
    if currentStatus == .notDetermined {
      Task {
        let newStatus = await permissionService.requestCameraPermission()
        await MainActor.run {
          cameraPermissionStatus = newStatus
        }
      }
    } else {
      cameraPermissionStatus = currentStatus
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



