//
//  RingingView.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  Enforced fullscreen ringing view for MVP1
//

import SwiftUI
import UIKit

struct RingingView: View {
    let alarmID: UUID
    @StateObject private var viewModel: DismissalFlowViewModel
    @EnvironmentObject private var container: DependencyContainer
    
    init(alarmID: UUID) {
        self.alarmID = alarmID
        self._viewModel = StateObject(wrappedValue: {
            DependencyContainer.shared.makeDismissalFlowViewModel()
        }())
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Main content based on state
                switch viewModel.state {
                case .idle:
                    ProgressView("Loading...")
                        .tint(.white)
                        .foregroundColor(.white)
                    
                case .ringing:
                    RingingContent(beginScan: { viewModel.beginScan() })
                    
                case .scanning:
                    ScanningContent(
                        cancelScan: { viewModel.cancelScan() },
                        onScanned: { payload in viewModel.didScan(payload: payload) }
                    )
                    
                case .validating:
                    ValidatingContent()
                    
                case .success:
                    SuccessContent()
                    
                case .failed(let reason):
                    FailedContent(reason: reason, retry: { viewModel.retry() })
                }
                
                Spacer()
                
                // Optional snooze button at bottom
                if viewModel.state == .ringing {
                    Button("Snooze (5 min)") {
                        viewModel.snooze()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .task {
            viewModel.start(alarmId: alarmID)
        }
        .onAppear {
            setupCallbacks()
        }
        .onDisappear {
            // Ensure audio stops when view disappears
            stopRingingAudio()
        }
    }
    
    private func setupCallbacks() {
        viewModel.onRequestScreenAwake = { awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        
        viewModel.onRequestAudioControl = { shouldPlay in
            Task { @MainActor in
                if shouldPlay {
                    await startRingingAudio()
                } else {
                    stopRingingAudio()
                }
            }
        }
        
        viewModel.onRequestHaptics = {
            // Trigger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }
    
  private func startRingingAudio() async {
    // Get the alarm to determine sound settings
    guard let alarm = try? container.persistenceService.alarm(with: alarmID) else {
            return
    }
        
        // Start continuous ringing with the alarm's sound and volume
        await container.audioService.startRinging(
            soundName: alarm.soundName, 
            volume: alarm.volume, 
            loop: true
        )
    }
    
    private func stopRingingAudio() {
        container.audioService.stop()
    }
}

// MARK: - State-specific Content Views

private struct RingingContent: View {
    let beginScan: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("ALARM")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Tap to start dismissal process")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("Scan Code to Dismiss") {
                beginScan()
            }
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .frame(minHeight: 44) // Accessibility: 44pt minimum tap target
            .accessibilityLabel("Scan Code to Dismiss")
            .accessibilityHint("Starts QR code scanner to dismiss the alarm")
        }
    }
}

private struct ScanningContent: View {
    let cancelScan: () -> Void
    let onScanned: (String) -> Void  // Add callback parameter
    @EnvironmentObject private var container: DependencyContainer
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Scanning QR Code")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Position the QR code within the scanner")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            // Actual QR Scanner Integration
            QRScannerView(
                onCancel: cancelScan,
                onScanned: onScanned,  // Connect to actual callback
                permissionService: container.permissionService
            )
            .frame(width: 280, height: 280)
            .cornerRadius(12)
            .clipped()
            
            Button("Cancel", action: cancelScan)
                .font(.title2)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .frame(minHeight: 44) // Accessibility: 44pt minimum tap target
                .accessibilityLabel("Cancel QR Code Scanning")
        }
    }
}

private struct ValidatingContent: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)
            
            Text("Validating QR Code...")
                .font(.title2)
                .foregroundColor(.white)
        }
    }
}

private struct SuccessContent: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Alarm Dismissed!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Successfully validated QR code")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

private struct FailedContent: View {
    let reason: DismissalFlowViewModel.FailureReason
    let retry: () -> Void
    @EnvironmentObject private var container: DependencyContainer
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: reason == .permissionDenied ? "camera.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(reason == .permissionDenied ? .orange : .red)
            
            Text(reason == .permissionDenied ? "Camera Access Required" : "Error")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(reason.displayMessage)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                if reason == .permissionDenied {
                    Button("Open Settings") {
                        container.permissionService.openAppSettings()
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Text("In Settings: Privacy & Security → Camera → alarmAppNew → Enable")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                } else {
                    Button("Try Again") {
                        retry()
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
}

#Preview {
    RingingView(alarmID: UUID())
        .environmentObject(DependencyContainer.shared)
}
