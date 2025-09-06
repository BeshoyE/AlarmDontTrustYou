//
//  PermissionService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/28/25.
//

import Foundation
import UserNotifications
import AVFoundation
import UIKit

// MARK: - Permission Status
enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    
    var isFirstTimeRequest: Bool {
        return self == .notDetermined
    }
    
    var requiresSettingsNavigation: Bool {
        return self == .denied
    }
}

// MARK: - Notification Permission Details
struct NotificationPermissionDetails {
    let authorizationStatus: PermissionStatus
    let alertsEnabled: Bool
    let soundEnabled: Bool
    let badgeEnabled: Bool
    
    var isAuthorizedButMuted: Bool {
        return authorizationStatus == .authorized && !soundEnabled
    }
    
    var isFullyAuthorized: Bool {
        return authorizationStatus == .authorized && alertsEnabled && soundEnabled
    }
    
    var userGuidanceText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Tap 'Allow Notifications' to enable alarm notifications."
        case .denied:
            return "Go to Settings → Notifications → alarmAppNew → Allow Notifications"
        case .authorized:
            if isAuthorizedButMuted {
                return "Go to Settings → Notifications → alarmAppNew → Enable Sounds"
            } else {
                return "Notifications are properly configured."
            }
        }
    }
}

// MARK: - Permission Service Protocol
protocol PermissionServiceProtocol {
    func requestNotificationPermission() async throws -> PermissionStatus
    func checkNotificationPermission() async -> NotificationPermissionDetails
    func requestCameraPermission() async -> PermissionStatus
    func checkCameraPermission() -> PermissionStatus
    func openAppSettings()
}

// MARK: - Permission Service Implementation
class PermissionService: PermissionServiceProtocol {
    
    // MARK: - Notification Permissions
    func requestNotificationPermission() async throws -> PermissionStatus {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        } catch {
            throw error
        }
    }
    
    func checkNotificationPermission() async -> NotificationPermissionDetails {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        let authStatus: PermissionStatus
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            authStatus = .authorized
        case .denied:
            authStatus = .denied
        case .notDetermined:
            authStatus = .notDetermined
        case .ephemeral:
            authStatus = .authorized
        @unknown default:
            authStatus = .notDetermined
        }
        
        return NotificationPermissionDetails(
            authorizationStatus: authStatus,
            alertsEnabled: settings.alertSetting == .enabled,
            soundEnabled: settings.soundSetting == .enabled,
            badgeEnabled: settings.badgeSetting == .enabled
        )
    }
    
    // MARK: - Camera Permissions
    func requestCameraPermission() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                let status: PermissionStatus = granted ? .authorized : .denied
                continuation.resume(returning: status)
            }
        }
    }
    
    func checkCameraPermission() -> PermissionStatus {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    // MARK: - Settings Navigation
    @MainActor 
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}