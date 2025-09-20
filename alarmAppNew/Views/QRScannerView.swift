//
//  QRScannerView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI
import CodeScanner
import AVFoundation


struct QRScannerView: View {
  @Environment(\.dismiss) private var dismiss
  let onCancel: () -> Void
  let onScanned: (String) -> Void
  let permissionService: PermissionServiceProtocol
  
  @State private var cameraPermissionStatus: PermissionStatus = .notDetermined
  @State private var showPermissionBlocking = false
  @State private var isTorchOn = false

  var body: some View {
    NavigationStack {
      Group {
        if cameraPermissionStatus == .authorized {
          CodeScannerView(
            codeTypes: [.qr],
            simulatedData: "Test QR Data",
            completion: handleScan
          )
          .onChange(of: isTorchOn) { _, newValue in
            setTorch(newValue)
          }
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
          
          ToolbarItem(placement: .primaryAction) {
            Button(action: { isTorchOn.toggle() }) {
              Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .foregroundColor(isTorchOn ? .yellow : .primary)
            }
            .accessibilityLabel("Toggle Torch")
            .accessibilityHint("Toggles the camera flash to help scan QR codes in dark environments")
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
      onScanned(scan.string)   // no dismiss() here
    case .failure:
      onCancel()               // no dismiss() here
    }
  }

  private func setTorch(_ on: Bool) {
      #if targetEnvironment(simulator)
      return // no torch in simulator
      #else
      guard let device = AVCaptureDevice.default(for: .video),
            device.hasTorch else { return }
      do {
          try device.lockForConfiguration()
          if on {
              try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
          } else {
              device.torchMode = .off
          }
          device.unlockForConfiguration()
      } catch {
          print("Torch could not be used: \(error)")
      }
      #endif
  }


}



