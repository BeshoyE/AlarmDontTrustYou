//
//  PermissionBlockingView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/28/25.
//

import SwiftUI

struct NotificationPermissionBlockingView: View {
    let permissionService: PermissionServiceProtocol
    let onPermissionGranted: () -> Void
    
    @State private var isRequestingPermission = false
    @State private var permissionDetails: NotificationPermissionDetails?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Notifications Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Alarms need notification permission to wake you up reliably. Without this permission, your alarms won't work.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                if let details = permissionDetails {
                    Text(details.userGuidanceText)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                }
            }
            
            VStack(spacing: 16) {
                if let details = permissionDetails {
                    if details.authorizationStatus.isFirstTimeRequest {
                        // First time - show system permission request
                        Button {
                            requestPermission()
                        } label: {
                            HStack {
                                if isRequestingPermission {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Allow Notifications")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRequestingPermission)
                    } else {
                        // Permission denied - only show Settings option
                        Button {
                            permissionService.openAppSettings()
                        } label: {
                            Text("Open Settings")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Loading state
                    ProgressView("Checking permissions...")
                }
                
                if permissionDetails?.authorizationStatus.requiresSettingsNavigation == true {
                    Text("After opening Settings, navigate to:\nNotifications → alarmAppNew → Allow Notifications")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .onAppear {
            checkPermissionStatus()
        }
    }
    
    private func checkPermissionStatus() {
        Task {
            let details = await permissionService.checkNotificationPermission()
            await MainActor.run {
                self.permissionDetails = details
            }
        }
    }
    
    private func requestPermission() {
        // Only attempt system request if status is notDetermined
        guard permissionDetails?.authorizationStatus.isFirstTimeRequest == true else {
            permissionService.openAppSettings()
            return
        }
        
        isRequestingPermission = true
        
        Task {
            do {
                let status = try await permissionService.requestNotificationPermission()
                
                await MainActor.run {
                    isRequestingPermission = false
                    
                    if status == .authorized {
                        onPermissionGranted()
                    } else {
                        // Permission denied, refresh status to show Settings UI
                        checkPermissionStatus()
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    checkPermissionStatus()
                }
            }
        }
    }
}

struct CameraPermissionBlockingView: View {
    let permissionService: PermissionServiceProtocol
    let onPermissionGranted: () -> Void
    let onCancel: () -> Void
    
    @State private var isRequestingPermission = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("To dismiss your alarm, you need to scan a QR code. Please allow camera access to use the QR scanner.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    Button {
                        requestPermission()
                    } label: {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Enable Camera")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequestingPermission)
                    
                    Button {
                        permissionService.openAppSettings()
                    } label: {
                        Text("Open Settings")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .navigationTitle("Camera Permission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func requestPermission() {
        isRequestingPermission = true
        
        Task {
            let status = await permissionService.requestCameraPermission()
            
            await MainActor.run {
                isRequestingPermission = false
                
                if status == .authorized {
                    onPermissionGranted()
                }
            }
        }
    }
}

// MARK: - Inline Warning Components
struct NotificationPermissionInlineWarning: View {
    let permissionDetails: NotificationPermissionDetails
    let permissionService: PermissionServiceProtocol
    
    var body: some View {
        if permissionDetails.authorizationStatus != .authorized {
            PermissionWarningCard(
                icon: "bell.slash.fill",
                title: "Notifications Disabled",
                message: "Enable notifications to schedule alarms",
                buttonText: "Open Settings",
                color: .orange,
                action: {
                    permissionService.openAppSettings()
                },
                detailInstructions: "In Settings: Notifications → alarmAppNew → Allow Notifications"
            )
        } else if permissionDetails.isAuthorizedButMuted {
            PermissionWarningCard(
                icon: "speaker.slash.fill",
                title: "Sound Disabled",
                message: "Your alarms are scheduled but won't make sound",
                buttonText: "Open Settings",
                color: .yellow,
                action: {
                    permissionService.openAppSettings()
                },
                detailInstructions: "In Settings: Notifications → alarmAppNew → Enable Sounds"
            )
        }
    }
}

struct PermissionWarningCard: View {
    let icon: String
    let title: String
    let message: String
    let buttonText: String
    let color: Color
    let detailInstructions: String?
    let action: () -> Void
    
    
    init(
        icon: String,
        title: String,
        message: String,
        buttonText: String,
        color: Color,
        action: @escaping () -> Void,
        detailInstructions: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonText = buttonText
        self.color = color
        self.action = action
        self.detailInstructions = detailInstructions
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(color)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(buttonText) {
                    action()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            if let instructions = detailInstructions {
                Text(instructions)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        NotificationPermissionBlockingView(
            permissionService: PermissionService(),
            onPermissionGranted: {}
        )
    }
}

#Preview {
    CameraPermissionBlockingView(
        permissionService: PermissionService(),
        onPermissionGranted: {},
        onCancel: {}
    )
}