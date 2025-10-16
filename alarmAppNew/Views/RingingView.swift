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
    let intentAlarmID: UUID?  // Intent-provided ID (could be pre-migration)
    @StateObject private var viewModel: DismissalFlowViewModel
    @EnvironmentObject private var container: DependencyContainer

    init(alarmID: UUID, intentAlarmID: UUID? = nil, container: DependencyContainer) {
        self.alarmID = alarmID
        self.intentAlarmID = intentAlarmID
        // Pass intent ID to ViewModel through factory
        self._viewModel = StateObject(wrappedValue: container.makeDismissalFlowViewModel(intentAlarmID: intentAlarmID))
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
                        onScanned: { payload in
                            Task {
                                await viewModel.didScan(payload: payload)
                            }
                        }
                    )
                    
                case .validating:
                    ValidatingContent()
                    
                case .success:
                    SuccessContent()
                    
                case .failed(let reason):
                    FailedContent(reason: reason, retry: { viewModel.retry() })
                }
                
                Spacer()

                // Stop and Snooze buttons at bottom
                if viewModel.state == .ringing {
                    VStack(spacing: 16) {
                        // Stop button (enabled only when challenges complete)
                        Button {
                            Task {
                                await viewModel.stopAlarm()
                            }
                        } label: {
                            Text("Stop Alarm")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.canStopAlarm ? Color.red : Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.canStopAlarm)
                        .accessibilityLabel("Stop Alarm")
                        .accessibilityHint(viewModel.canStopAlarm ? "Stops the alarm" : "Complete challenges first to stop the alarm")

                        // Snooze button
                        if viewModel.canSnooze {
                            Button {
                                Task {
                                    await viewModel.snooze()
                                }
                            } label: {
                                Text("Snooze (5 min)")
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.3))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .accessibilityLabel("Snooze for 5 minutes")
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
            .padding()
        }
        .task {
            await viewModel.start(alarmId: alarmID)
        }
        .onAppear {
            setupCallbacks()
        }
        .onDisappear {
            // Ensure cleanup when view disappears
            viewModel.cleanup()
        }
    }

    private func setupCallbacks() {
        viewModel.onRequestHaptics = {
            // Trigger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
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
    let container = DependencyContainer()
    return RingingView(alarmID: UUID(), container: container)
        .environmentObject(container)
        .environment(\.container, container)
}
