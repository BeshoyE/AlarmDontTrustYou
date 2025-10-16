# alarmAppNew - Production Codebase Export

Generated: 2025-10-11

Total Files: 77

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Models/Weekdays.swift

```swift
//
//  Weekdays.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

enum Weekdays: Int, Codable, CaseIterable, Equatable {

  case sunday = 1
  case monday = 2
  case tuesday = 3
  case wednesday = 4
  case thursday = 5
  case friday = 6
  case saturday = 7

  var displayName: String {
    switch self {
    case .sunday: return "Sun"
    case .monday: return "Mon"
    case .tuesday: return "Tues"
    case .wednesday: return "Wed"
    case .thursday: return "Thurs"
    case .friday: return "Friday"
    case .saturday: return "Saturday"
    }
  }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Models/MathChallenge.swift

```swift
//
//  MathChallenge.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

struct MathChallenge: Codable, Equatable, Hashable {
  let number: Int
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Extensions/View+DismissalFlow.swift

```swift
////
////  View+DismissalFlow.swift
////  alarmAppNew
////
////  Created by Beshoy Eskarous on 7/24/25.
////
//
//import SwiftUI
//
//extension View {
//  func dismissalFLow(for alarmID: Binding<UUID?>) -> some View {
//    self.fullScreenCover(item: alarmID) { id in
//      let vm = DismissalFlowViewModel(alarmID: id)
//      DismissalFlowView(viewModel: vm) {
//        alarmID.wrappedValue = nil
//      }
//    }
//  }
//}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Coordinators/AppCoordinator.swift

```swift
//
//  AppCoordinator.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI


class AppCoordinator: ObservableObject {
  @Published var alarmToDismiss: UUID? = nil

  func showDismissal (for alarmID: UUID) {
    alarmToDismiss = alarmID
  }

  func dismissalCompleted() {    alarmToDismiss = nil
  }
}

```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/PermissionService.swift

```swift
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
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/PermissionBlockingView.swift

```swift
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
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Models/AlarmRun.swift

```swift

import Foundation

enum AlarmOutcome: String, Codable {
  case success
  case failed
  
}

struct AlarmRun: Identifiable, Equatable, Codable {
  let id: UUID
  let alarmId: UUID
  let firedAt: Date
  var dismissedAt: Date?
  var outcome: AlarmOutcome
  
  // MARK: - Helper Factories
  
  static func fired(alarmId: UUID, at time: Date = Date()) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: time,
      dismissedAt: nil,
      outcome: .failed // Default to failed until explicitly dismissed
    )
  }
  
  static func successful(alarmId: UUID, firedAt: Date, dismissedAt: Date) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: firedAt,
      dismissedAt: dismissedAt,
      outcome: .success
    )
  }
  
  static func failed(alarmId: UUID, firedAt: Date) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: firedAt,
      dismissedAt: nil,
      outcome: .failed
    )
  }
  
  // MARK: - Mutations
  
  mutating func markDismissed(at time: Date = Date()) {
    dismissedAt = time
    outcome = .success
  }
  
  mutating func markFailed() {
    outcome = .failed
    dismissedAt = nil
  }
}


```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Sounds/AlarmSound.swift

```swift
//
//  AlarmSound.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public struct AlarmSound: Identifiable, Codable, Equatable {
    public let id: String         // stable key, e.g. "chimes01"
    public let name: String       // display label
    public let fileName: String   // includes extension, e.g. "chimes01.caf"
    public let durationSec: Int   // >0; descriptive only

    public init(id: String, name: String, fileName: String, durationSec: Int) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.durationSec = durationSec
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Sounds/SoundCatalogProviding.swift

```swift
//
//  SoundCatalogProviding.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public protocol SoundCatalogProviding {
    var all: [AlarmSound] { get }
    var defaultSoundId: String { get }
    func info(for id: String) -> AlarmSound?
}

// MARK: - Safe Helper Extension

public extension SoundCatalogProviding {
    /// Safe sound lookup that falls back to default if ID is missing or invalid
    /// Prevents UI crashes when dealing with unknown sound IDs
    func safeInfo(for id: String?) -> AlarmSound? {
        if let id = id, let sound = info(for: id) {
            return sound
        }
        return info(for: defaultSoundId)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Alarms/AlarmFactory.swift

```swift
//
//  AlarmFactory.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public protocol AlarmFactory {
    /// Creates a new alarm with sensible defaults, including a valid soundId from the sound catalog
    func makeNewAlarm() -> Alarm
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Alarms/DefaultAlarmFactory.swift

```swift
//
//  DefaultAlarmFactory.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public final class DefaultAlarmFactory: AlarmFactory {
    private let catalog: SoundCatalogProviding

    public init(catalog: SoundCatalogProviding) {
        self.catalog = catalog
    }

    public func makeNewAlarm() -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600), // Default to 1 hour from now
            label: "New Alarm",
            repeatDays: [],
            challengeKind: [],
            expectedQR: nil,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: catalog.defaultSoundId,  // Use catalog's default sound
            soundName: nil,                   // Legacy field - will be phased out
            volume: 0.8
        )
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Time/NowProvider.swift

```swift
//
//  ClockExtensions.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

// Note: Clock protocol is defined in DismissalFlowViewModel.swift
// This file extends it with test utilities

public struct MockClock: Clock {
    public var fixedNow: Date

    public init(fixedNow: Date = Date()) {
        self.fixedNow = fixedNow
    }

    public func now() -> Date {
        return fixedNow
    }

    public mutating func advance(by timeInterval: TimeInterval) {
        fixedNow = fixedNow.addingTimeInterval(timeInterval)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/ViewModels/AlarmDetailViewModel.swift

```swift
//
//  AlarmDetailViewModel.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/22/25.
//

import SwiftUI

class AlarmDetailViewModel:ObservableObject, Identifiable {
  let id = UUID()
  @Published var draft: Alarm
  let isNewAlarm: Bool

  
  init(alarm: Alarm, isNew: Bool = false) {
    self.draft = alarm
    self.isNewAlarm = isNew
  }

  var isValid: Bool {
    //qr challenge is either not selected or qr var is not empty
    let qrOK = !draft.challengeKind.contains(.qr) || (draft.expectedQR?.isEmpty == false)
    let soundOK = !draft.soundId.isEmpty
    let volumeOK = draft.volume >= 0.0 && draft.volume <= 1.0
    return qrOK && soundOK && volumeOK && !draft.label.isEmpty
  }

  func commitChanges() -> Alarm {
    return draft
  }

  func repeatBinding(for day: Weekdays) -> Binding<Bool> {
    Binding<Bool> (
      get: {self.draft.repeatDays.contains(day) },
      set: { isOn in
        if isOn {
          if !self.draft.repeatDays.contains(day){
            self.draft.repeatDays.append(day)
          }
        } else {
          self.draft.repeatDays.removeAll { $0 == day }
        }
      }
    )
  }

  func removeChallenge(_ kind: Challenges) {
    draft.challengeKind.removeAll{$0 == kind}
    if kind == .qr {
      draft.expectedQR = nil
    }
  }
  
  // MARK: - Sound Management

  func updateSound(_ soundId: String) {
    draft.soundId = soundId
    // Keep soundName in sync for backward compatibility
    draft.soundName = soundId
  }
  
  func updateVolume(_ volume: Double) {
    draft.volume = max(0.0, min(1.0, volume))
  }
  
  var volumeBinding: Binding<Double> {
    Binding<Double>(
      get: { self.draft.volume },
      set: { self.updateVolume($0) }
    )
  }
  
  var soundIdBinding: Binding<String> {
    Binding<String>(
      get: { self.draft.soundId },
      set: { self.updateSound($0) }
    )
  }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/AudioCapability.swift

```swift
//
//  AudioCapability.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/2/25.
//  Abstraction layer for audio playback capabilities
//

import Foundation

/// Defines what audio playback capabilities are allowed
public enum AudioCapability {
    case none                 // No AVAudioPlayer ever
    case foregroundAssist     // AVAudioPlayer only when app active & alarm fires
    case sleepMode            // AVAudioPlayer in background (sleep) + at alarm
}

/// Policy that combines capability with routing preferences
public struct AudioPolicy {
    public let capability: AudioCapability
    public let allowRouteOverrideAtAlarm: Bool  // Duck/stop others

    public init(capability: AudioCapability, allowRouteOverrideAtAlarm: Bool) {
        self.capability = capability
        self.allowRouteOverrideAtAlarm = allowRouteOverrideAtAlarm
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/QRScannerView.swift

```swift
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



```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/QRScanningService.swift

```swift
//
//  QRScanningService.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  QR scanning service implementation
//

import Foundation
import AVFoundation

// Service implementation using existing QRScannerView infrastructure
class QRScanningService: QRScanning {
    private let permissionService: PermissionServiceProtocol
    private var continuation: AsyncStream<String>.Continuation?
    private var isScanning = false
    
    init(permissionService: PermissionServiceProtocol) {
        self.permissionService = permissionService
    }
    
    func startScanning() async throws {
        guard !isScanning else { return }
        
        // Check/request camera permission
        let status = await permissionService.requestCameraPermission()
        guard status == .authorized else {
            throw QRScanningError.permissionDenied
        }
        
        isScanning = true
    }
    
    func stopScanning() {
        isScanning = false
        continuation?.finish()
        continuation = nil
    }
    
    func scanResultStream() -> AsyncStream<String> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    // Called by QRScannerView when scan completes
    func didScanQR(_ payload: String) {
        guard isScanning else { return }
        continuation?.yield(payload)
    }
}

enum QRScanningError: Error, LocalizedError {
    case permissionDenied
    case scanningFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission is required for QR scanning"
        case .scanningFailed:
            return "QR scanning failed"
        }
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/AudioSessionConfig.swift

```swift
//
//  AudioSessionConfig.swift
//  alarmAppNew
//
//  Audio session configuration constants
//

import Foundation

/// Configuration for audio session behavior
public enum AudioSessionConfig {
    /// Grace period after deactivating audio session before allowing new sounds
    /// This ensures the session fully deactivates before iOS plays subsequent notification sounds
    /// Default: 120ms (sufficient for most devices to complete deactivation)
    public static let deactivationGraceNs: UInt64 = 120_000_000  // 120ms in nanoseconds
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Persistence/DismissedRegistry.swift

```swift
//
//  DismissedRegistry.swift
//  alarmAppNew
//
//  Tracks dismissed alarm occurrences to prevent duplicate dismissal flows
//

import Foundation

/// Registry tracking which alarm occurrences have been successfully dismissed
/// Prevents re-showing dismissal flow on app restart when delivered notifications persist
@MainActor
final class DismissedRegistry {
    private struct DismissedOccurrence: Codable {
        let alarmId: UUID
        let occurrenceKey: String
        let dismissedAt: Date
    }

    private let userDefaults: UserDefaults
    private let storageKey = "com.alarmapp.dismissedOccurrences"
    private let expirationWindow: TimeInterval = 300  // 5 minutes

    private var cache: [String: DismissedOccurrence] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCache()
    }

    /// Mark an occurrence as dismissed (pure persistence - no OS cleanup)
    func markDismissed(alarmId: UUID, occurrenceKey: String) {
        let key = cacheKey(alarmId: alarmId, occurrenceKey: occurrenceKey)
        let occurrence = DismissedOccurrence(
            alarmId: alarmId,
            occurrenceKey: occurrenceKey,
            dismissedAt: Date()
        )

        cache[key] = occurrence
        persistCache()

        let alarmIdPrefix = String(alarmId.uuidString.prefix(8))
        let keyPrefix = String(occurrenceKey.prefix(10))
        print("📋 DismissedRegistry: Marked", alarmIdPrefix + "/" + keyPrefix + "...", "as dismissed")
    }

    /// Check if an occurrence was already dismissed recently
    func isDismissed(alarmId: UUID, occurrenceKey: String) -> Bool {
        let key = cacheKey(alarmId: alarmId, occurrenceKey: occurrenceKey)

        guard let occurrence = cache[key] else {
            return false
        }

        // Check if dismissal is still within expiration window
        let isExpired = Date().timeIntervalSince(occurrence.dismissedAt) > expirationWindow
        if isExpired {
            // Clean up expired entry
            cache.removeValue(forKey: key)
            persistCache()
            return false
        }

        return true
    }

    /// Get all dismissed occurrence keys for startup cleanup
    func dismissedOccurrenceKeys() -> Set<String> {
        return Set(cache.values.map { $0.occurrenceKey })
    }

    /// Clear all dismissed occurrences (for testing/reset)
    func clearAll() {
        cache.removeAll()
        userDefaults.removeObject(forKey: storageKey)
        print("📋 DismissedRegistry: Cleared all dismissed occurrences")
    }

    /// Clean up expired occurrences (call periodically)
    func cleanupExpired() {
        let now = Date()
        let expiredKeys = cache.filter { _, occurrence in
            now.timeIntervalSince(occurrence.dismissedAt) > expirationWindow
        }.map { $0.key }

        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }

        if !expiredKeys.isEmpty {
            persistCache()
            print("📋 DismissedRegistry: Cleaned up \(expiredKeys.count) expired occurrences")
        }
    }

    // MARK: - Private Helpers

    private func cacheKey(alarmId: UUID, occurrenceKey: String) -> String {
        return "\(alarmId.uuidString)|\(occurrenceKey)"
    }

    private func loadCache() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: DismissedOccurrence].self, from: data) else {
            return
        }

        cache = decoded
        cleanupExpired()  // Clean on load
    }

    private func persistCache() {
        guard let encoded = try? JSONEncoder().encode(cache) else {
            print("⚠️ DismissedRegistry: Failed to encode cache")
            return
        }

        userDefaults.set(encoded, forKey: storageKey)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/OccurrenceKeyFormatter.swift

```swift
//
//  OccurrenceKeyFormatter.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/5/25.
//  Shared formatter for occurrence keys used in notification identifiers and dismissal tracking
//

import Foundation

/// Shared formatter for occurrence keys used in notification identifiers and dismissal tracking
/// Ensures consistency between notification scheduling, cleanup, and testing
public enum OccurrenceKeyFormatter {
    /// Generate occurrence key from fire date
    /// Format: ISO8601 with fractional seconds (e.g., "2025-10-05T14:30:00.000Z")
    public static func key(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Parse occurrence key back to date (for validation/testing)
    public static func date(from key: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: key)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Notifications/NotificationIdentifiers.swift

```swift
//
//  NotificationIdentifiers.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

public struct NotificationIdentifier {
    public let alarmId: UUID
    public let fireDate: Date
    public let occurrence: Int

    public init(alarmId: UUID, fireDate: Date, occurrence: Int) {
        self.alarmId = alarmId
        self.fireDate = fireDate
        self.occurrence = occurrence
    }

    public var stringValue: String {
        let dateString = OccurrenceKeyFormatter.key(from: fireDate)
        return "alarm-\(alarmId.uuidString)-occ-\(dateString)-\(occurrence)"
    }

    public static func parse(_ identifier: String) -> NotificationIdentifier? {
        // Expected format: "alarm-{uuid}-occ-{ISO8601}-{occurrence}"
        guard identifier.hasPrefix("alarm-") else { return nil }

        // Remove "alarm-" prefix
        let withoutPrefix = String(identifier.dropFirst(6))

        // Find the UUID part (36 characters + hyphen)
        guard withoutPrefix.count > 37 else { return nil }
        let uuidString = String(withoutPrefix.prefix(36))
        guard let alarmId = UUID(uuidString: uuidString) else { return nil }

        // Remove UUID and the following hyphen
        let remainder = String(withoutPrefix.dropFirst(37))

        // Should start with "occ-"
        guard remainder.hasPrefix("occ-") else { return nil }

        // Remove "occ-" prefix
        let dateAndOccurrence = String(remainder.dropFirst(4))

        // Find the last hyphen which separates the occurrence number
        guard let lastHyphenIndex = dateAndOccurrence.lastIndex(of: "-") else { return nil }

        // Split into date and occurrence
        let dateString = String(dateAndOccurrence[..<lastHyphenIndex])
        let occurrenceString = String(dateAndOccurrence[dateAndOccurrence.index(after: lastHyphenIndex)...])

        // Parse occurrence
        guard let occurrence = Int(occurrenceString) else { return nil }

        // Parse date
        guard let fireDate = OccurrenceKeyFormatter.date(from: dateString) else { return nil }

        return NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: occurrence)
    }
}

extension NotificationIdentifier: Codable, Equatable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }
}

public struct NotificationIdentifierBatch {
    public let alarmId: UUID
    public let identifiers: [NotificationIdentifier]

    public init(alarmId: UUID, identifiers: [NotificationIdentifier]) {
        self.alarmId = alarmId
        self.identifiers = identifiers
    }

    public var stringValues: [String] {
        return identifiers.map(\.stringValue)
    }
}

extension NotificationIdentifierBatch: Codable, Equatable {}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/RefreshRequesting.swift

```swift
//
//  RefreshRequesting.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/7/25.
//  Protocol for requesting notification refresh operations
//

import Foundation

/// Protocol for requesting notification refresh operations
protocol RefreshRequesting {
    func requestRefresh(alarms: [Alarm]) async
}

// RefreshCoordinator already has the exact method signature
// Just declare conformance without implementing anything
extension RefreshCoordinator: RefreshRequesting {}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Policies/ChainSettingsProvider.swift

```swift
//
//  ChainSettingsProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

public protocol ChainSettingsProviding {
    func chainSettings() -> ChainSettings
    func validateSettings(_ settings: ChainSettings) -> ChainSettingsValidationResult
}

public enum ChainSettingsValidationResult {
    case valid
    case invalid(reasons: [String])

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    public var errorReasons: [String] {
        if case .invalid(let reasons) = self { return reasons }
        return []
    }
}

public final class DefaultChainSettingsProvider: ChainSettingsProviding {

    public init() {}

    public func chainSettings() -> ChainSettings {
        // Production defaults optimized for "continuous ring" feel
        // - maxChainCount: 12 (up from 5) for better coverage over 5-minute window
        // - fallbackSpacingSec: 10 (down from 30) for faster repetition when sound duration unknown
        // - minLeadTimeSec: 10 to ensure iOS fires notifications reliably
        // - Spacing auto-adjusts to sound duration when available (e.g., 27s for chimes01)
        return ChainSettings(
            maxChainCount: 12,
            ringWindowSec: 300,
            fallbackSpacingSec: 10,
            minLeadTimeSec: 10
        )
    }

    public func validateSettings(_ settings: ChainSettings) -> ChainSettingsValidationResult {
        var errors: [String] = []

        // Validate chain count
        if settings.maxChainCount < 1 {
            errors.append("maxChainCount must be at least 1")
        }
        if settings.maxChainCount > 15 {
            errors.append("maxChainCount should not exceed 15 (iOS notification limit considerations)")
        }

        // Validate ring window
        if settings.ringWindowSec < 30 {
            errors.append("ringWindowSec must be at least 30 seconds")
        }
        if settings.ringWindowSec > 600 {
            errors.append("ringWindowSec should not exceed 600 seconds (10 minutes)")
        }

        // Validate fallback spacing
        if settings.fallbackSpacingSec < 5 {
            errors.append("fallbackSpacingSec must be at least 5 seconds")
        }
        if settings.fallbackSpacingSec > 60 {
            errors.append("fallbackSpacingSec should not exceed 60 seconds")
        }

        // Validate minimum lead time
        if settings.minLeadTimeSec < 5 {
            errors.append("minLeadTimeSec must be at least 5 seconds")
        }
        if settings.minLeadTimeSec > 30 {
            errors.append("minLeadTimeSec should not exceed 30 seconds")
        }

        // Cross-validation: ensure ring window can accommodate at least one chain
        let minPossibleDuration = settings.fallbackSpacingSec * settings.maxChainCount
        if settings.ringWindowSec < minPossibleDuration {
            errors.append("ringWindowSec too small for maxChainCount at fallbackSpacingSec")
        }

        return errors.isEmpty ? .valid : .invalid(reasons: errors)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Policies/ChainPolicy.swift

```swift
//
//  ChainPolicy.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

public struct ChainConfiguration {
    public let spacingSeconds: Int
    public let chainCount: Int
    public let totalDurationSeconds: Int

    public init(spacingSeconds: Int, chainCount: Int) {
        self.spacingSeconds = spacingSeconds
        self.chainCount = chainCount
        self.totalDurationSeconds = spacingSeconds * max(1, chainCount)
    }

    public func trimmed(to maxCount: Int) -> ChainConfiguration {
        let actualCount = max(1, min(chainCount, maxCount))
        return ChainConfiguration(spacingSeconds: spacingSeconds, chainCount: actualCount)
    }
}

public struct ChainSettings {
    public let maxChainCount: Int
    public let ringWindowSec: Int
    public let fallbackSpacingSec: Int
    public let minLeadTimeSec: Int
    public let cleanupGraceSec: Int

    public init(maxChainCount: Int = 12, ringWindowSec: Int = 180, fallbackSpacingSec: Int = 30, minLeadTimeSec: Int = 10, cleanupGraceSec: Int = 60) {
        // Validate and clamp to safe ranges
        let clampedMax = max(1, min(50, maxChainCount))
        let clampedWindow = max(30, min(600, ringWindowSec))
        let clampedSpacing = max(1, min(30, fallbackSpacingSec))
        let clampedLeadTime = max(5, min(30, minLeadTimeSec))
        let clampedGrace = max(30, min(300, cleanupGraceSec))

        self.maxChainCount = clampedMax
        self.ringWindowSec = clampedWindow
        self.fallbackSpacingSec = clampedSpacing
        self.minLeadTimeSec = clampedLeadTime
        self.cleanupGraceSec = clampedGrace

        // Log any coercions for observability
        if maxChainCount != clampedMax {
            os_log("ChainSettings: clamped maxChainCount %d -> %d",
                   log: .default, type: .info, maxChainCount, clampedMax)
        }
        if ringWindowSec != clampedWindow {
            os_log("ChainSettings: clamped ringWindowSec %d -> %d",
                   log: .default, type: .info, ringWindowSec, clampedWindow)
        }
        if fallbackSpacingSec != clampedSpacing {
            os_log("ChainSettings: clamped fallbackSpacingSec %d -> %d",
                   log: .default, type: .info, fallbackSpacingSec, clampedSpacing)
        }
        if minLeadTimeSec != clampedLeadTime {
            os_log("ChainSettings: clamped minLeadTimeSec %d -> %d",
                   log: .default, type: .info, minLeadTimeSec, clampedLeadTime)
        }
        if cleanupGraceSec != clampedGrace {
            os_log("ChainSettings: clamped cleanupGraceSec %d -> %d",
                   log: .default, type: .info, cleanupGraceSec, clampedGrace)
        }
    }
}

public struct ChainPolicy {
    public let settings: ChainSettings

    public init(settings: ChainSettings = ChainSettings()) {
        self.settings = settings
    }

    public func normalizedSpacing(_ rawSeconds: Int) -> Int {
        return max(1, min(30, rawSeconds))
    }

    public func computeChain(spacingSeconds: Int) -> ChainConfiguration {
        let normalizedSpacing = normalizedSpacing(spacingSeconds)

        // Calculate how many notifications fit in the ring window
        let theoreticalCount = settings.ringWindowSec / normalizedSpacing

        // Cap at configured maximum and ensure at least 1
        let actualCount = max(1, min(settings.maxChainCount, theoreticalCount))

        return ChainConfiguration(spacingSeconds: normalizedSpacing, chainCount: actualCount)
    }

    public func computeFireDates(baseFireDate: Date, configuration: ChainConfiguration) -> [Date] {
        var dates: [Date] = []

        for occurrence in 0..<configuration.chainCount {
            let offsetSeconds = TimeInterval(occurrence * configuration.spacingSeconds)
            let fireDate = baseFireDate.addingTimeInterval(offsetSeconds)
            dates.append(fireDate)
        }

        return dates
    }
}

// MARK: - Extensions for convenience

extension ChainSettings: Codable, Equatable {
    public static let defaultSettings = ChainSettings()
}

extension ChainConfiguration: Equatable {
    public static func == (lhs: ChainConfiguration, rhs: ChainConfiguration) -> Bool {
        return lhs.spacingSeconds == rhs.spacingSeconds &&
               lhs.chainCount == rhs.chainCount
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Persistence/NotificationIndex.swift

```swift
//
//  NotificationIndex.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

// MARK: - Chain Metadata

public struct ChainMeta: Codable {
    public let start: Date          // Actual start time (shifted for minLeadTime)
    public let spacing: TimeInterval
    public let count: Int
    public let createdAt: Date      // When this chain was scheduled

    public init(start: Date, spacing: TimeInterval, count: Int, createdAt: Date) {
        self.start = start
        self.spacing = spacing
        self.count = count
        self.createdAt = createdAt
    }
}

public protocol NotificationIndexProviding {
    func saveIdentifiers(alarmId: UUID, identifiers: [String])
    func loadIdentifiers(alarmId: UUID) -> [String]
    func clearIdentifiers(alarmId: UUID)
    func getAllPendingIdentifiers() -> [String]
    func clearAllIdentifiers()
    func allTrackedAlarmIds() -> [UUID]
    func removeIdentifiers(alarmId: UUID, identifiers: [String])

    // Chain metadata persistence
    func saveChainMeta(alarmId: UUID, meta: ChainMeta)
    func loadChainMeta(alarmId: UUID) -> ChainMeta?
    func clearChainMeta(alarmId: UUID)
}

public final class NotificationIndex: NotificationIndexProviding {
    private let defaults: UserDefaults
    private let keyPrefix = "notification_index"
    private let metaKeyPrefix = "notification_meta"
    private let globalKey = "notification_index_global"
    private let log = OSLog(subsystem: "alarmAppNew", category: "NotificationIndex")

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public Interface

    public func saveIdentifiers(alarmId: UUID, identifiers: [String]) {
        let key = makeKey(for: alarmId)

        os_log("Saving %d identifiers for alarm %@",
               log: log, type: .info, identifiers.count, alarmId.uuidString)

        if identifiers.isEmpty {
            // Remove the key entirely if no identifiers
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(identifiers, forKey: key)
        }

        // Update global index
        updateGlobalIndex()

        #if DEBUG
        // Verify the save in debug builds
        let savedIdentifiers = loadIdentifiers(alarmId: alarmId)
        assert(savedIdentifiers == identifiers, "Identifier save verification failed")
        #endif
    }

    public func loadIdentifiers(alarmId: UUID) -> [String] {
        let key = makeKey(for: alarmId)
        let identifiers = defaults.stringArray(forKey: key) ?? []

        os_log("Loaded %d identifiers for alarm %@",
               log: log, type: .debug, identifiers.count, alarmId.uuidString)

        return identifiers
    }

    public func clearIdentifiers(alarmId: UUID) {
        let key = makeKey(for: alarmId)

        os_log("Clearing identifiers for alarm %@",
               log: log, type: .info, alarmId.uuidString)

        defaults.removeObject(forKey: key)
        updateGlobalIndex()
    }

    public func getAllPendingIdentifiers() -> [String] {
        let globalIdentifiers = defaults.stringArray(forKey: globalKey) ?? []

        os_log("Retrieved %d total pending identifiers",
               log: log, type: .debug, globalIdentifiers.count)

        return globalIdentifiers
    }

    public func clearAllIdentifiers() {
        os_log("Clearing all notification identifiers and metadata", log: log, type: .info)

        // Find all alarm-specific keys (both identifiers and metadata)
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter { $0.hasPrefix(keyPrefix) && $0 != globalKey }
        let metaKeys = allKeys.filter { $0.hasPrefix(metaKeyPrefix) }

        for key in notificationKeys {
            defaults.removeObject(forKey: key)
        }

        for key in metaKeys {
            defaults.removeObject(forKey: key)
        }

        // Clear global index
        defaults.removeObject(forKey: globalKey)

        os_log("Cleared %d identifier keys and %d metadata keys",
               log: log, type: .info, notificationKeys.count, metaKeys.count)
    }

    public func allTrackedAlarmIds() -> [UUID] {
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter {
            $0.hasPrefix("\(keyPrefix)_") && $0 != globalKey
        }

        let alarmIds = notificationKeys.compactMap { key -> UUID? in
            let uuidString = key.replacingOccurrences(of: "\(keyPrefix)_", with: "")
            return UUID(uuidString: uuidString)
        }

        os_log("Found %d tracked alarm IDs", log: log, type: .debug, alarmIds.count)
        return alarmIds
    }

    public func removeIdentifiers(alarmId: UUID, identifiers: [String]) {
        var current = loadIdentifiers(alarmId: alarmId)
        let initialCount = current.count

        current.removeAll { identifiers.contains($0) }

        os_log("Removing %d identifiers from alarm %@ (had: %d, now: %d)",
               log: log, type: .info, initialCount - current.count,
               alarmId.uuidString, initialCount, current.count)

        if current.isEmpty {
            clearIdentifiers(alarmId: alarmId)
        } else {
            saveIdentifiers(alarmId: alarmId, identifiers: current)
        }
    }

    // MARK: - Chain Metadata Persistence

    public func saveChainMeta(alarmId: UUID, meta: ChainMeta) {
        let key = makeMetaKey(for: alarmId)

        do {
            let data = try JSONEncoder().encode(meta)
            defaults.set(data, forKey: key)

            os_log("Saved chain metadata for alarm %@ (start: %@, count: %d)",
                   log: log, type: .info, alarmId.uuidString,
                   meta.start.ISO8601Format(), meta.count)
        } catch {
            os_log("Failed to save chain metadata for alarm %@: %@",
                   log: log, type: .error, alarmId.uuidString, error.localizedDescription)
        }
    }

    public func loadChainMeta(alarmId: UUID) -> ChainMeta? {
        let key = makeMetaKey(for: alarmId)

        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            let meta = try JSONDecoder().decode(ChainMeta.self, from: data)
            os_log("Loaded chain metadata for alarm %@ (start: %@, count: %d)",
                   log: log, type: .debug, alarmId.uuidString,
                   meta.start.ISO8601Format(), meta.count)
            return meta
        } catch {
            os_log("Failed to decode chain metadata for alarm %@: %@",
                   log: log, type: .error, alarmId.uuidString, error.localizedDescription)
            return nil
        }
    }

    public func clearChainMeta(alarmId: UUID) {
        let key = makeMetaKey(for: alarmId)
        defaults.removeObject(forKey: key)

        os_log("Cleared chain metadata for alarm %@",
               log: log, type: .info, alarmId.uuidString)
    }

    // MARK: - Private Helpers

    private func makeKey(for alarmId: UUID) -> String {
        return "\(keyPrefix)_\(alarmId.uuidString)"
    }

    private func makeMetaKey(for alarmId: UUID) -> String {
        return "\(metaKeyPrefix)_\(alarmId.uuidString)"
    }

    private func updateGlobalIndex() {
        // Aggregate all identifiers across all alarms
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter {
            $0.hasPrefix(keyPrefix) && $0 != globalKey
        }

        var allIdentifiers: [String] = []

        for key in notificationKeys {
            if let identifiers = defaults.stringArray(forKey: key) {
                allIdentifiers.append(contentsOf: identifiers)
            }
        }

        os_log("Updating global index with %d total identifiers from %d alarms",
               log: log, type: .debug, allIdentifiers.count, notificationKeys.count)

        if allIdentifiers.isEmpty {
            defaults.removeObject(forKey: globalKey)
        } else {
            defaults.set(allIdentifiers, forKey: globalKey)
        }
    }
}

// MARK: - Convenience Extensions

extension NotificationIndex {
    public func saveIdentifierBatch(_ batch: NotificationIdentifierBatch) {
        saveIdentifiers(alarmId: batch.alarmId, identifiers: batch.stringValues)
    }

    public func loadIdentifierBatch(alarmId: UUID) -> NotificationIdentifierBatch {
        let identifiers = loadIdentifiers(alarmId: alarmId)
        let parsedIdentifiers = identifiers.compactMap(NotificationIdentifier.parse)
        return NotificationIdentifierBatch(alarmId: alarmId, identifiers: parsedIdentifiers)
    }

    public func idempotentReschedule(
        alarmId: UUID,
        expectedIdentifiers: [String],
        completion: () -> Void
    ) {
        // Load current identifiers
        let currentIdentifiers = loadIdentifiers(alarmId: alarmId)

        os_log("Idempotent reschedule for alarm %@: current=%d expected=%d",
               log: log, type: .info, alarmId.uuidString,
               currentIdentifiers.count, expectedIdentifiers.count)

        // Clear current identifiers first
        clearIdentifiers(alarmId: alarmId)

        // Execute the reschedule operation
        completion()

        // Save the new expected identifiers
        saveIdentifiers(alarmId: alarmId, identifiers: expectedIdentifiers)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Sounds/SoundCatalog.swift

```swift
//
//  SoundCatalog.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public final class SoundCatalog: SoundCatalogProviding {
    private let sounds: [AlarmSound]
    public let defaultSoundId: String

    public init(bundle: Bundle = .main, validateFiles: Bool = true) {
        // Static catalog - only include actually bundled sounds
        // For now, we only have ringtone1.caf bundled
        self.sounds = [
            AlarmSound(id: "ringtone1", name: "Ringtone", fileName: "ringtone1.caf", durationSec: 27)
        ]

        // Use the actual bundled sound as default
        self.defaultSoundId = "ringtone1"

        if validateFiles {
            validate(bundle: bundle)
        }
    }

    public var all: [AlarmSound] {
        sounds
    }

    public func info(for id: String) -> AlarmSound? {
        sounds.first { $0.id == id }
    }

    private func validate(bundle: Bundle) {
        // Validate unique IDs
        let uniqueIds = Set(sounds.map { $0.id })
        assert(uniqueIds.count == sounds.count, "SoundCatalog: Duplicate sound IDs detected")

        // Validate positive durations
        assert(sounds.allSatisfy { $0.durationSec > 0 }, "SoundCatalog: All durations must be > 0")

        // Validate default ID exists
        assert(info(for: defaultSoundId) != nil, "SoundCatalog: defaultSoundId '\(defaultSoundId)' must exist in catalog")

        // Validate bundle files existence
        for sound in sounds {
            let fileName = sound.fileName
            let nameWithoutExtension = (fileName as NSString).deletingPathExtension
            let fileExtension = (fileName as NSString).pathExtension

            let exists = bundle.url(forResource: nameWithoutExtension, withExtension: fileExtension) != nil

            #if DEBUG
            assert(exists, "SoundCatalog: Missing sound file in bundle: \(fileName)")
            #else
            if !exists {
                print("SoundCatalog WARNING: Missing sound file '\(fileName)'; will use default at schedule time")
            }
            #endif
        }

        print("✅ SoundCatalog: Validation complete - \(sounds.count) sounds, default: '\(defaultSoundId)'")
    }
}

// MARK: - Preview Support

public extension SoundCatalog {
    /// Catalog for SwiftUI previews and tests - bypasses file validation
    static let preview = SoundCatalog(validateFiles: false)
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Services/ScheduleOutcome.swift

```swift
//
//  ScheduleOutcome.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

public enum UnavailableReason {
    case permissions
    case globalLimit
    case invalidConfiguration
    case other(Error)
}

public enum ScheduleOutcome {
    case scheduled(count: Int)
    case trimmed(original: Int, scheduled: Int)
    case unavailable(reason: UnavailableReason)

    public var isSuccess: Bool {
        switch self {
        case .scheduled, .trimmed:
            return true
        case .unavailable:
            return false
        }
    }

    public var scheduledCount: Int {
        switch self {
        case .scheduled(let count):
            return count
        case .trimmed(_, let scheduled):
            return scheduled
        case .unavailable:
            return 0
        }
    }
}

extension ScheduleOutcome: Equatable {
    public static func == (lhs: ScheduleOutcome, rhs: ScheduleOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.scheduled(let lhsCount), .scheduled(let rhsCount)):
            return lhsCount == rhsCount
        case (.trimmed(let lhsOriginal, let lhsScheduled), .trimmed(let rhsOriginal, let rhsScheduled)):
            return lhsOriginal == rhsOriginal && lhsScheduled == rhsScheduled
        case (.unavailable(let lhsReason), .unavailable(let rhsReason)):
            // Simple comparison - could be enhanced for specific error types
            return String(describing: lhsReason) == String(describing: rhsReason)
        default:
            return false
        }
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/ActiveAlarmPolicyProvider.swift

```swift
//
//  ActiveAlarmPolicyProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Computes active alarm windows from chain configuration (no magic numbers)
//

import Foundation

/// Protocol for determining if an alarm occurrence is currently active
/// (i.e., should be protected from cancellation during refreshAll)
public protocol ActiveAlarmPolicyProviding {
    /// Compute the active window duration for an alarm occurrence
    /// Returns the number of seconds from the occurrence fire time during which
    /// the alarm is considered "active" and should not be cancelled
    func activeWindowSeconds(for alarmId: UUID, occurrenceKey: String) -> TimeInterval
}

/// Default implementation that derives the active window from chain configuration
/// Formula: window = min(((count-1) * spacing) + leadIn + tolerance, maxCap)
///
/// Rationale:
/// - The chain spans from first notification to last notification
/// - Duration = (count-1) * spacing (e.g., 12 notifications * 10s = 110s from first to last)
/// - Add leadIn (minLeadTimeSec) for scheduling overhead
/// - Add tolerance for device/OS delays
/// - Cap at ringWindowSec to prevent unbounded windows
public final class ActiveAlarmPolicyProvider: ActiveAlarmPolicyProviding {
    private let chainPolicy: ChainPolicy
    private let toleranceSeconds: TimeInterval

    /// Initialize with chain policy and tolerance
    /// - Parameters:
    ///   - chainPolicy: The chain configuration policy (provides spacing, count, leadIn)
    ///   - toleranceSeconds: Additional buffer for device/OS delays (default: 10s)
    public init(chainPolicy: ChainPolicy, toleranceSeconds: TimeInterval = 10.0) {
        self.chainPolicy = chainPolicy
        self.toleranceSeconds = toleranceSeconds
    }

    public func activeWindowSeconds(for alarmId: UUID, occurrenceKey: String) -> TimeInterval {
        // Compute the chain configuration using the same logic as scheduling
        // Default spacing is 10s (this is what ChainedNotificationScheduler uses)
        let defaultSpacing = 10
        let chainConfig = chainPolicy.computeChain(spacingSeconds: defaultSpacing)

        // Calculate the duration from first to last notification in the chain
        // For a chain of N notifications spaced S seconds apart:
        // - First fires at T=0
        // - Last fires at T=(N-1)*S
        // - Total span = (N-1) * S
        let chainSpan = TimeInterval((chainConfig.chainCount - 1) * chainConfig.spacingSeconds)

        // Add leadIn time (scheduling overhead)
        let leadIn = TimeInterval(chainPolicy.settings.minLeadTimeSec)

        // Add tolerance for device delays
        let tolerance = toleranceSeconds

        // Compute total active window
        let computedWindow = chainSpan + leadIn + tolerance

        // Cap at the ring window to prevent unbounded windows
        let maxCap = TimeInterval(chainPolicy.settings.ringWindowSec)
        let activeWindow = min(computedWindow, maxCap)

        return activeWindow
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/OccurrenceKey.swift

```swift
//
//  OccurrenceKey.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Pure Swift utility for occurrence key value type and parsing extensions
//

import Foundation

/// Value type representing a unique occurrence of an alarm
/// Used to identify specific instances of repeating alarms
public struct OccurrenceKey: Equatable, Hashable {
    public let date: Date

    public init(date: Date) {
        self.date = date
    }
}

/// Extension to OccurrenceKeyFormatter for parsing notification identifiers
/// Complements the existing key(from:) method in OccurrenceKeyFormatter.swift
extension OccurrenceKeyFormatter {

    // MARK: - Parsing

    /// Parse an occurrence key from a notification identifier
    /// Expected format: "alarm-{uuid}-occ-{ISO8601}-{index}"
    /// Example: "alarm-12345678-1234-1234-1234-123456789012-occ-2025-10-09T00:15:00Z-0"
    public static func parse(fromIdentifier identifier: String) -> OccurrenceKey? {
        guard let date = parseDate(from: identifier) else {
            return nil
        }
        return OccurrenceKey(date: date)
    }

    /// Parse just the date component from an identifier
    /// Returns nil if the identifier doesn't match the expected format
    public static func parseDate(from identifier: String) -> Date? {
        // Split by "-occ-" to isolate the occurrence portion
        let parts = identifier.components(separatedBy: "-occ-")
        guard parts.count >= 2 else {
            return nil
        }

        // The second part contains: "{ISO8601}-{index}"
        // Split by last "-" to remove the index
        let occurrencePart = parts[1]
        let occurrenceComponents = occurrencePart.components(separatedBy: "-")

        // ISO8601 format is "YYYY-MM-DDTHH:MM:SSZ" or "YYYY-MM-DDTHH:MM:SS.sssZ"
        // This contains 2 internal "-" characters (YYYY-MM-DD)
        // So we need at least 3 components: [YYYY, MM, DD...] + potential index at end
        guard occurrenceComponents.count >= 3 else {
            return nil
        }

        // Reconstruct the ISO8601 string by taking all but the last component
        // (the last component is the index number)
        let iso8601String = occurrenceComponents.dropLast().joined(separator: "-")

        // Parse ISO8601 string to Date (use existing method for consistency)
        return date(from: iso8601String)
    }

    /// Parse the alarm ID from an identifier
    /// Expected format: "alarm-{uuid}-occ-{ISO8601}-{index}"
    public static func parseAlarmId(from identifier: String) -> UUID? {
        // Split by "-occ-" to isolate the alarm portion
        let parts = identifier.components(separatedBy: "-occ-")
        guard parts.count >= 2 else {
            return nil
        }

        // The first part is "alarm-{uuid}"
        let alarmPart = parts[0]

        // Remove "alarm-" prefix
        guard alarmPart.hasPrefix("alarm-") else {
            return nil
        }

        let uuidString = String(alarmPart.dropFirst("alarm-".count))
        return UUID(uuidString: uuidString)
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/DeliveredNotificationsReader.swift

```swift
//
//  DeliveredNotificationsReader.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Protocol adapter for reading delivered notifications (Infrastructure → Domain boundary)
//

import Foundation
import UserNotifications

/// Simplified representation of a delivered notification
/// Domain-friendly model without iOS framework dependencies
public struct DeliveredNotification {
    public let identifier: String
    public let deliveredDate: Date

    public init(identifier: String, deliveredDate: Date) {
        self.identifier = identifier
        self.deliveredDate = deliveredDate
    }
}

/// Protocol for reading delivered notifications
/// Wraps UNUserNotificationCenter.getDeliveredNotifications() behind a testable interface
public protocol DeliveredNotificationsReading {
    func getDeliveredNotifications() async -> [DeliveredNotification]
}

/// Default implementation that wraps UNUserNotificationCenter
public final class UNDeliveredNotificationsReader: DeliveredNotificationsReading {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func getDeliveredNotifications() async -> [DeliveredNotification] {
        let notifications = await center.deliveredNotifications()
        return notifications.map { notification in
            DeliveredNotification(
                identifier: notification.request.identifier,
                deliveredDate: notification.date
            )
        }
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/SettingsService.swift

```swift
//
//  SettingsService.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation
import Combine

// MARK: - Settings Errors

enum SettingsError: Error, LocalizedError {
    case intervalsNotSorted
    case invalidInterval
    case leadInOutOfRange

    var errorDescription: String? {
        switch self {
        case .intervalsNotSorted:
            return "Alert intervals must be sorted in ascending order"
        case .invalidInterval:
            return "Alert intervals must be non-negative"
        case .leadInOutOfRange:
            return "Lead-in time must be between 0 and 60 seconds"
        }
    }
}

// MARK: - Reliability Mode

enum ReliabilityMode: String, CaseIterable {
    case notificationsOnly = "notifications_only"
    case notificationsPlusAudio = "notifications_plus_audio"

    var displayName: String {
        switch self {
        case .notificationsOnly:
            return "Notifications Only (App Store Safe)"
        case .notificationsPlusAudio:
            return "Notifications + Background Audio (Experimental)"
        }
    }

    var description: String {
        switch self {
        case .notificationsOnly:
            return "Uses only system notifications for alarms. App Store compliant."
        case .notificationsPlusAudio:
            return "Adds background audio session management. For testing only."
        }
    }
}

// MARK: - Protocol for Dependency Injection

@MainActor
protocol ReliabilityModeProvider {
    var currentMode: ReliabilityMode { get }
    var modePublisher: AnyPublisher<ReliabilityMode, Never> { get }
}

// MARK: - Settings Service Protocol

@MainActor
protocol SettingsServiceProtocol: ReliabilityModeProvider {
    var useChainedScheduling: Bool { get }
    var useAudioEnhancement: Bool { get }
    var alertIntervalsSec: [Int] { get }
    var suppressForegroundSound: Bool { get }
    var leadInSec: Int { get }
    var foregroundAlarmBoost: Double { get }
    var audioPolicy: AudioPolicy { get }

    func setReliabilityMode(_ mode: ReliabilityMode)
    func setUseChainedScheduling(_ enabled: Bool)
    func setUseAudioEnhancement(_ enabled: Bool)
    func setAlertIntervals(_ intervals: [Int]) throws
    func setSuppressForegroundSound(_ enabled: Bool)
    func setLeadInSec(_ seconds: Int) throws
    func setForegroundAlarmBoost(_ boost: Double)
    func resetToDefaults()
}

// MARK: - Settings Service Implementation

@MainActor
final class SettingsService: SettingsServiceProtocol, ObservableObject {

    // MARK: - Constants

    private enum Keys {
        static let reliabilityMode = "com.alarmApp.reliabilityMode"
        static let useChainedScheduling = "com.alarmApp.useChainedScheduling"
        static let useAudioEnhancement = "com.alarmApp.useAudioEnhancement"
        static let alertIntervalsSec = "com.alarmApp.alertIntervalsSec"
        static let suppressForegroundSound = "com.alarmApp.suppressForegroundSound"
        static let leadInSec = "com.alarmApp.leadInSec"
        static let foregroundAlarmBoost = "com.alarmApp.foregroundAlarmBoost"
    }

    // MARK: - Published Properties

    @Published private(set) var currentMode: ReliabilityMode = .notificationsOnly
    @Published private(set) var useChainedScheduling: Bool = true
    @Published private(set) var useAudioEnhancement: Bool = false
    @Published private(set) var alertIntervalsSec: [Int] = [0, 10, 20]
    @Published private(set) var suppressForegroundSound: Bool = true
    @Published private(set) var leadInSec: Int = 2
    @Published private(set) var foregroundAlarmBoost: Double = 1.0  // Range: 0.8-1.5

    // MARK: - Dependencies

    private let userDefaults: UserDefaults
    private let audioEngine: AlarmAudioEngineProtocol
    private let subject = CurrentValueSubject<ReliabilityMode, Never>(.notificationsOnly)

    // MARK: - Public Properties

    var modePublisher: AnyPublisher<ReliabilityMode, Never> {
        subject.eraseToAnyPublisher()
    }

    var audioPolicy: AudioPolicy {
        switch currentMode {
        case .notificationsOnly:
            return AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
        case .notificationsPlusAudio:
            return AudioPolicy(capability: .sleepMode, allowRouteOverrideAtAlarm: true)
        }
    }

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard, audioEngine: AlarmAudioEngineProtocol) {
        self.userDefaults = userDefaults
        self.audioEngine = audioEngine

        // Load persisted settings or use defaults
        loadPersistedMode()
        loadChainedSchedulingPreference()
        loadAudioEnhancementSettings()

        print("🔧 SettingsService: Initialized with mode: \(currentMode.rawValue), chainedScheduling: \(useChainedScheduling), audioEnhancement: \(useAudioEnhancement)")
    }

    // MARK: - Public Methods

    func setReliabilityMode(_ mode: ReliabilityMode) {
        let previousMode = currentMode

        guard previousMode != mode else {
            print("🔧 SettingsService: Mode already set to \(mode.rawValue) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing reliability mode: \(previousMode.rawValue) → \(mode.rawValue)")

        // CRITICAL: If switching to notifications only, immediately stop any active audio
        if mode == .notificationsOnly && audioEngine.currentState != .idle {
            print("🔇 SettingsService: IMMEDIATE STOP - switching to notifications only")
            audioEngine.stop() // This performs full teardown
        }

        // Update current mode
        currentMode = mode

        // Persist the change
        userDefaults.set(mode.rawValue, forKey: Keys.reliabilityMode)

        // Notify subscribers
        subject.send(mode)

        print("🔧 SettingsService: ✅ Mode change complete: \(mode.rawValue)")
    }

    func setUseChainedScheduling(_ enabled: Bool) {
        guard useChainedScheduling != enabled else {
            print("🔧 SettingsService: Chained scheduling already set to \(enabled) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing chained scheduling: \(useChainedScheduling) → \(enabled)")
        useChainedScheduling = enabled
        userDefaults.set(enabled, forKey: Keys.useChainedScheduling)
        print("🔧 SettingsService: ✅ Chained scheduling changed to: \(enabled)")
    }

    func setUseAudioEnhancement(_ enabled: Bool) {
        // Audio enhancement can only be enabled when in notificationsPlusAudio mode
        guard currentMode == .notificationsPlusAudio || !enabled else {
            print("🔧 SettingsService: ⚠️ Cannot enable audio enhancement in notifications-only mode")
            return
        }

        guard useAudioEnhancement != enabled else {
            print("🔧 SettingsService: Audio enhancement already set to \(enabled) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing audio enhancement: \(useAudioEnhancement) → \(enabled)")
        useAudioEnhancement = enabled
        userDefaults.set(enabled, forKey: Keys.useAudioEnhancement)
        print("🔧 SettingsService: ✅ Audio enhancement changed to: \(enabled)")
    }

    func setAlertIntervals(_ intervals: [Int]) throws {
        // Validation: Must be sorted ascending
        guard intervals == intervals.sorted() else {
            throw SettingsError.intervalsNotSorted
        }

        // Validation: All intervals must be non-negative
        guard intervals.allSatisfy({ $0 >= 0 }) else {
            throw SettingsError.invalidInterval
        }

        print("🔧 SettingsService: Changing alert intervals: \(alertIntervalsSec) → \(intervals)")
        alertIntervalsSec = intervals
        userDefaults.set(intervals, forKey: Keys.alertIntervalsSec)
        print("🔧 SettingsService: ✅ Alert intervals changed to: \(intervals)")
    }

    func setSuppressForegroundSound(_ enabled: Bool) {
        guard suppressForegroundSound != enabled else {
            print("🔧 SettingsService: Suppress foreground sound already set to \(enabled) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing suppress foreground sound: \(suppressForegroundSound) → \(enabled)")
        suppressForegroundSound = enabled
        userDefaults.set(enabled, forKey: Keys.suppressForegroundSound)
        print("🔧 SettingsService: ✅ Suppress foreground sound changed to: \(enabled)")
    }

    func setLeadInSec(_ seconds: Int) throws {
        // Validation: Must be 0-60 seconds
        guard (0...60).contains(seconds) else {
            throw SettingsError.leadInOutOfRange
        }

        print("🔧 SettingsService: Changing lead-in seconds: \(leadInSec) → \(seconds)")
        leadInSec = seconds
        userDefaults.set(seconds, forKey: Keys.leadInSec)
        print("🔧 SettingsService: ✅ Lead-in seconds changed to: \(seconds)")
    }

    func setForegroundAlarmBoost(_ boost: Double) {
        // Clamp to valid range: 0.8-1.5
        let clampedBoost = max(0.8, min(1.5, boost))

        guard foregroundAlarmBoost != clampedBoost else {
            print("🔧 SettingsService: Foreground alarm boost already set to \(clampedBoost) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing foreground alarm boost: \(foregroundAlarmBoost) → \(clampedBoost)")
        foregroundAlarmBoost = clampedBoost
        userDefaults.set(clampedBoost, forKey: Keys.foregroundAlarmBoost)
        print("🔧 SettingsService: ✅ Foreground alarm boost changed to: \(clampedBoost)")
    }

    func resetToDefaults() {
        print("🔧 SettingsService: Resetting to defaults")
        setReliabilityMode(.notificationsOnly)
        setUseChainedScheduling(true)
        setUseAudioEnhancement(false)
        try? setAlertIntervals([0, 10, 20])
        setSuppressForegroundSound(true)
        try? setLeadInSec(2)
        setForegroundAlarmBoost(1.0)
    }

    // MARK: - Private Methods

    private func loadPersistedMode() {
        let rawValue = userDefaults.string(forKey: Keys.reliabilityMode)

        if let rawValue = rawValue,
           let persistedMode = ReliabilityMode(rawValue: rawValue) {
            currentMode = persistedMode
            print("🔧 SettingsService: Loaded persisted mode: \(persistedMode.rawValue)")
        } else {
            currentMode = .notificationsOnly
            print("🔧 SettingsService: Using default mode: \(currentMode.rawValue)")
        }

        // Initialize the subject with the loaded mode
        subject.send(currentMode)
    }

    private func loadChainedSchedulingPreference() {
        // Default to true if not set (enable new feature by default)
        if userDefaults.object(forKey: Keys.useChainedScheduling) == nil {
            useChainedScheduling = true
            userDefaults.set(true, forKey: Keys.useChainedScheduling)
            print("🔧 SettingsService: Using default chained scheduling: true")
        } else {
            useChainedScheduling = userDefaults.bool(forKey: Keys.useChainedScheduling)
            print("🔧 SettingsService: Loaded persisted chained scheduling: \(useChainedScheduling)")
        }
    }

    private func loadAudioEnhancementSettings() {
        // Load useAudioEnhancement (default: false, only enable in notificationsPlusAudio mode)
        if userDefaults.object(forKey: Keys.useAudioEnhancement) == nil {
            useAudioEnhancement = false
            userDefaults.set(false, forKey: Keys.useAudioEnhancement)
            print("🔧 SettingsService: Using default audio enhancement: false")
        } else {
            let persistedValue = userDefaults.bool(forKey: Keys.useAudioEnhancement)
            // Enforce constraint: can only be true in notificationsPlusAudio mode
            useAudioEnhancement = persistedValue && currentMode == .notificationsPlusAudio
            print("🔧 SettingsService: Loaded audio enhancement: \(useAudioEnhancement) (persisted: \(persistedValue))")
        }

        // Load alertIntervalsSec (default: [0, 10, 20])
        if let persistedIntervals = userDefaults.array(forKey: Keys.alertIntervalsSec) as? [Int], !persistedIntervals.isEmpty {
            alertIntervalsSec = persistedIntervals
            print("🔧 SettingsService: Loaded alert intervals: \(alertIntervalsSec)")
        } else {
            alertIntervalsSec = [0, 10, 20]
            userDefaults.set(alertIntervalsSec, forKey: Keys.alertIntervalsSec)
            print("🔧 SettingsService: Using default alert intervals: \(alertIntervalsSec)")
        }

        // Load suppressForegroundSound (default: true)
        if userDefaults.object(forKey: Keys.suppressForegroundSound) == nil {
            suppressForegroundSound = true
            userDefaults.set(true, forKey: Keys.suppressForegroundSound)
            print("🔧 SettingsService: Using default suppress foreground sound: true")
        } else {
            suppressForegroundSound = userDefaults.bool(forKey: Keys.suppressForegroundSound)
            print("🔧 SettingsService: Loaded suppress foreground sound: \(suppressForegroundSound)")
        }

        // Load leadInSec (default: 2)
        if userDefaults.object(forKey: Keys.leadInSec) == nil {
            leadInSec = 2
            userDefaults.set(2, forKey: Keys.leadInSec)
            print("🔧 SettingsService: Using default lead-in seconds: 2")
        } else {
            leadInSec = userDefaults.integer(forKey: Keys.leadInSec)
            print("🔧 SettingsService: Loaded lead-in seconds: \(leadInSec)")
        }

        // Load foregroundAlarmBoost (default: 1.0, range: 0.8-1.5)
        if userDefaults.object(forKey: Keys.foregroundAlarmBoost) == nil {
            foregroundAlarmBoost = 1.0
            userDefaults.set(1.0, forKey: Keys.foregroundAlarmBoost)
            print("🔧 SettingsService: Using default foreground alarm boost: 1.0")
        } else {
            let persistedBoost = userDefaults.double(forKey: Keys.foregroundAlarmBoost)
            foregroundAlarmBoost = max(0.8, min(1.5, persistedBoost))  // Clamp to valid range
            print("🔧 SettingsService: Loaded foreground alarm boost: \(foregroundAlarmBoost)")
        }
    }
}

// MARK: - Mock for Testing

#if DEBUG
@MainActor
final class MockSettingsService: SettingsServiceProtocol {
    @Published private(set) var currentMode: ReliabilityMode = .notificationsOnly
    @Published var useChainedScheduling: Bool = true
    @Published var useAudioEnhancement: Bool = false
    @Published var alertIntervalsSec: [Int] = [0, 10, 20]
    @Published var suppressForegroundSound: Bool = true
    @Published var leadInSec: Int = 2
    @Published var foregroundAlarmBoost: Double = 1.0
    private let subject = CurrentValueSubject<ReliabilityMode, Never>(.notificationsOnly)

    var modePublisher: AnyPublisher<ReliabilityMode, Never> {
        subject.eraseToAnyPublisher()
    }

    var audioPolicy: AudioPolicy {
        switch currentMode {
        case .notificationsOnly:
            return AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
        case .notificationsPlusAudio:
            return AudioPolicy(capability: .sleepMode, allowRouteOverrideAtAlarm: true)
        }
    }

    func setReliabilityMode(_ mode: ReliabilityMode) {
        currentMode = mode
        subject.send(mode)
    }

    func setUseChainedScheduling(_ enabled: Bool) {
        useChainedScheduling = enabled
    }

    func setUseAudioEnhancement(_ enabled: Bool) {
        useAudioEnhancement = enabled
    }

    func setAlertIntervals(_ intervals: [Int]) throws {
        guard intervals == intervals.sorted() else {
            throw SettingsError.intervalsNotSorted
        }
        alertIntervalsSec = intervals
    }

    func setSuppressForegroundSound(_ enabled: Bool) {
        suppressForegroundSound = enabled
    }

    func setLeadInSec(_ seconds: Int) throws {
        guard (0...60).contains(seconds) else {
            throw SettingsError.leadInOutOfRange
        }
        leadInSec = seconds
    }

    func setForegroundAlarmBoost(_ boost: Double) {
        foregroundAlarmBoost = max(0.8, min(1.5, boost))
    }

    func resetToDefaults() {
        setReliabilityMode(.notificationsOnly)
        setUseChainedScheduling(true)
        setUseAudioEnhancement(false)
        try? setAlertIntervals([0, 10, 20])
        setSuppressForegroundSound(true)
        try? setLeadInSec(2)
        setForegroundAlarmBoost(1.0)
    }
}
#endif```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/DI/DependencyContainerKey.swift

```swift
//
//  DependencyContainerKey.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Environment key for dependency injection (eliminates singleton pattern)
//

import SwiftUI

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

extension EnvironmentValues {
    var container: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/SettingsView.swift

```swift
//
//  SettingsView.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsService: SettingsService
    @Environment(\.dismiss) private var dismiss

    init(container: DependencyContainer) {
        self.settingsService = container.settingsServiceConcrete
    }

    var body: some View {
        NavigationStack {
            Form {
                // General Settings Section
                Section("General") {
                    Text("App version and basic settings would go here in a full implementation")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

#if DEBUG
                // Developer Section - Only visible in DEBUG builds
                Section("Developer Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Reliability Mode Toggle
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Experimental: Background Audio Reliability")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { settingsService.currentMode == .notificationsPlusAudio },
                                    set: { isOn in
                                        let newMode: ReliabilityMode = isOn ? .notificationsPlusAudio : .notificationsOnly
                                        settingsService.setReliabilityMode(newMode)
                                    }
                                ))
                                .labelsHidden()
                            }

                            Text(settingsService.currentMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Warning Message
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Developer Warning")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }

                            Text("Background audio mode is experimental and may not be App Store compliant. Use only for testing purposes. Default 'Notifications Only' mode is App Store safe.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)

                        // Current Mode Status
                        HStack {
                            Text("Current Mode:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(settingsService.currentMode.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(settingsService.currentMode == .notificationsOnly ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .headerProminence(.increased)
#endif

                // Reset Section
                Section("Reset") {
                    Button("Reset to Defaults") {
                        settingsService.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = DependencyContainer()
    return SettingsView(container: container)
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/ChallengeSelectionView.swift

```swift
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

  // Inject container for accessing services
  private let container: DependencyContainer

  init(draft: Binding<Alarm>, container: DependencyContainer) {
      self._draft = draft
      self.container = container
  }

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
        permissionService: container.permissionService
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
    let container = DependencyContainer()
    return ChallengeSelectionView(
        draft: .constant(Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.math],  // Pre-populate with a challenge to see checkmark
            expectedQR: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )),
        container: container
    )
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Policies/AlarmPresentationPolicy.swift

```swift
//
//  AlarmPresentationPolicy.swift
//  alarmAppNew
//
//  Pure Swift policies for alarm presentation behavior.
//  These policies determine how alarms should be presented and controlled
//  without any dependency on specific UI frameworks.
//

import Foundation

/// Bounds for valid snooze durations.
public struct SnoozeBounds {
    /// Minimum allowed snooze duration in seconds
    public let min: TimeInterval

    /// Maximum allowed snooze duration in seconds
    public let max: TimeInterval

    public init(min: TimeInterval, max: TimeInterval) {
        // Ensure min <= max
        self.min = Swift.min(min, max)
        self.max = Swift.max(min, max)
    }

    /// Default snooze bounds (5 to 60 minutes)
    public static let `default` = SnoozeBounds(
        min: 5 * 60,   // 5 minutes
        max: 60 * 60   // 60 minutes
    )
}

/// Policies for alarm presentation and control behavior.
public struct AlarmPresentationPolicy {

    private let snoozeBounds: SnoozeBounds

    public init(snoozeBounds: SnoozeBounds = .default) {
        self.snoozeBounds = snoozeBounds
    }

    /// Determine if countdown should be shown for an alarm.
    /// - Parameter alarm: The alarm to check
    /// - Returns: True if countdown should be shown (snooze is enabled with valid duration)
    public func shouldShowCountdown(for alarm: Alarm) -> Bool {
        // Show countdown if alarm has snooze enabled
        // In the future, this will check alarm.snoozeEnabled and alarm.snoozeDuration
        // For now, we'll return false as snooze isn't implemented yet
        // TODO: Update when Alarm model includes snooze configuration
        return false
    }

    /// Determine if a live activity is required for an alarm.
    /// - Parameter alarm: The alarm to check
    /// - Returns: True if alarm needs a live activity (for countdown or pre-alarm features)
    public func requiresLiveActivity(for alarm: Alarm) -> Bool {
        // Live activity needed for:
        // 1. Snooze/countdown features
        // 2. Pre-alarm countdowns
        // For now, return same as shouldShowCountdown
        return shouldShowCountdown(for: alarm)
    }

    /// Check if a snooze duration is valid within configured bounds.
    /// - Parameters:
    ///   - duration: The requested snooze duration in seconds
    ///   - bounds: The snooze bounds to validate against
    /// - Returns: True if duration is within bounds
    public static func isSnoozeDurationValid(
        _ duration: TimeInterval,
        bounds: SnoozeBounds
    ) -> Bool {
        return duration >= bounds.min && duration <= bounds.max
    }

    /// Clamp a snooze duration to valid bounds.
    /// - Parameters:
    ///   - duration: The requested snooze duration in seconds
    ///   - bounds: The snooze bounds to clamp to
    /// - Returns: Duration clamped to [min, max] range
    public static func clampSnoozeDuration(
        _ duration: TimeInterval,
        bounds: SnoozeBounds
    ) -> TimeInterval {
        if duration < bounds.min {
            return bounds.min
        } else if duration > bounds.max {
            return bounds.max
        } else {
            return duration
        }
    }

    /// Determine the stop button semantics for an alarm.
    /// - Parameter challengesRequired: Whether challenges are configured for the alarm
    /// - Returns: Description of when stop button should be enabled
    public static func stopButtonSemantics(challengesRequired: Bool) -> StopButtonSemantics {
        if challengesRequired {
            return .requiresChallengeValidation
        } else {
            return .alwaysEnabled
        }
    }
}

/// Semantics for when the stop button should be enabled.
public enum StopButtonSemantics {
    /// Stop button is always enabled (no challenges required)
    case alwaysEnabled

    /// Stop button requires all challenges to be validated first
    case requiresChallengeValidation

    /// Human-readable description
    public var description: String {
        switch self {
        case .alwaysEnabled:
            return "Stop button is always enabled"
        case .requiresChallengeValidation:
            return "Stop button requires challenge completion"
        }
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/UseCases/SnoozeAlarm.swift

```swift
//
//  SnoozeAlarm.swift
//  alarmAppNew
//
//  Pure domain use case for calculating snooze times.
//  This handles DST transitions and timezone changes correctly.
//

import Foundation

/// Use case for snoozing an alarm.
///
/// This calculates the next fire time for a snoozed alarm, handling:
/// - Clamping duration to valid bounds
/// - DST transitions (fall back / spring forward)
/// - Timezone changes
/// - Local wall-clock time preservation
public struct SnoozeAlarm {

    /// Calculate the next fire time for a snoozed alarm.
    ///
    /// - Parameters:
    ///   - alarm: The alarm being snoozed
    ///   - now: The current time
    ///   - requestedSnooze: The requested snooze duration in seconds
    ///   - bounds: The valid snooze duration bounds
    ///   - calendar: Calendar to use for calculations (defaults to current)
    ///   - timeZone: TimeZone to use (defaults to current)
    /// - Returns: The next fire time for the alarm
    public static func execute(
        alarm: Alarm,
        now: Date,
        requestedSnooze: TimeInterval,
        bounds: SnoozeBounds,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Date {
        // Step 1: Clamp the snooze duration to valid bounds
        let clampedDuration = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedSnooze,
            bounds: bounds
        )

        // Step 2: Calculate next fire time using local components to handle DST
        var adjustedCalendar = calendar
        adjustedCalendar.timeZone = timeZone

        // Get current time components
        let currentComponents = adjustedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )

        // Add snooze duration
        let nextFireDate = now.addingTimeInterval(clampedDuration)

        // Get components of next fire time
        let nextComponents = adjustedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: nextFireDate
        )

        // Step 3: Handle DST transitions
        // If we're crossing a DST boundary, we need to ensure the alarm
        // fires at the intended local time
        if let reconstructedDate = adjustedCalendar.date(from: nextComponents) {
            // Check if the reconstructed date differs significantly from simple addition
            // This indicates a DST transition occurred
            let difference = abs(reconstructedDate.timeIntervalSince(nextFireDate))

            // If difference is more than a few seconds, we crossed DST
            if difference > 10 {
                // For DST transitions, prefer the local wall-clock time
                // This ensures alarm fires at the "expected" local time
                return handleDSTTransition(
                    originalDate: nextFireDate,
                    components: nextComponents,
                    calendar: adjustedCalendar
                )
            }

            return reconstructedDate
        }

        // Fallback to simple time addition if component reconstruction fails
        return nextFireDate
    }

    /// Handle DST transitions by ensuring alarm fires at intended local time.
    private static func handleDSTTransition(
        originalDate: Date,
        components: DateComponents,
        calendar: Calendar
    ) -> Date {
        // During spring forward: 2:30 AM becomes 3:30 AM
        // During fall back: 2:30 AM occurs twice

        // Try to create date from components
        guard let date = calendar.date(from: components) else {
            // If components are invalid (e.g., in spring forward gap),
            // find next valid time
            var adjustedComponents = components

            // Try adding an hour if we're in a gap
            if let hour = adjustedComponents.hour {
                adjustedComponents.hour = hour + 1
                if let adjustedDate = calendar.date(from: adjustedComponents) {
                    return adjustedDate
                }
            }

            // Fallback to original
            return originalDate
        }

        // For fall back, we might get the "first" 2:30 AM when we want the "second"
        // Check if we need to disambiguate
        let isDSTActive = calendar.timeZone.isDaylightSavingTime(for: originalDate)
        let willBeDSTActive = calendar.timeZone.isDaylightSavingTime(for: date)

        // If DST status changed, we crossed a boundary
        if isDSTActive != willBeDSTActive {
            // For fall back: prefer the later occurrence
            // For spring forward: already handled above
            if isDSTActive && !willBeDSTActive {
                // Fall back case: add DST offset to get "second" occurrence
                return date.addingTimeInterval(3600) // Add 1 hour
            }
        }

        return date
    }

    /// Calculate next fire time for a recurring alarm on a specific day.
    ///
    /// This is used when an alarm needs to fire on its next scheduled day,
    /// properly handling DST and timezone changes.
    public static func nextOccurrence(
        for alarm: Alarm,
        after date: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Date? {
        var adjustedCalendar = calendar
        adjustedCalendar.timeZone = timeZone

        // Get alarm time components
        let alarmComponents = adjustedCalendar.dateComponents(
            [.hour, .minute],
            from: alarm.time
        )

        guard let alarmHour = alarmComponents.hour,
              let alarmMinute = alarmComponents.minute else {
            return nil
        }

        // Start from tomorrow to find next occurrence
        guard let tomorrow = adjustedCalendar.date(byAdding: .day, value: 1, to: date) else {
            return nil
        }

        // Check up to 8 days ahead (covers all weekdays)
        for dayOffset in 0..<8 {
            guard let checkDate = adjustedCalendar.date(
                byAdding: .day,
                value: dayOffset,
                to: tomorrow
            ) else { continue }

            // Get weekday for this date
            let weekdayComponent = adjustedCalendar.component(.weekday, from: checkDate)

            // Check if alarm is scheduled for this weekday
            if alarm.repeatDays.isEmpty ||
               alarm.repeatDays.contains(where: { $0.calendarWeekday == weekdayComponent }) {
                // Create date with alarm time on this day
                var components = adjustedCalendar.dateComponents(
                    [.year, .month, .day],
                    from: checkDate
                )
                components.hour = alarmHour
                components.minute = alarmMinute
                components.second = 0

                if let fireDate = adjustedCalendar.date(from: components) {
                    return fireDate
                }
            }
        }

        return nil
    }
}

// MARK: - Helpers

private extension Weekdays {
    /// Convert to Calendar.Component weekday (1=Sunday, 7=Saturday)
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/UseCases/StopAlarmAllowed.swift

```swift
//
//  StopAlarmAllowed.swift
//  alarmAppNew
//
//  Pure domain use case for determining if an alarm can be stopped.
//  This enforces the business rule that alarms with challenges must
//  complete all challenges before the stop button is enabled.
//

import Foundation

/// State of challenge validation for an alarm.
public struct ChallengeStackState {
    /// The challenges configured for the alarm
    public let requiredChallenges: [Challenges]

    /// The challenges that have been completed
    public let completedChallenges: Set<Challenges>

    /// Whether challenges are currently being validated
    public let isValidating: Bool

    public init(
        requiredChallenges: [Challenges],
        completedChallenges: Set<Challenges>,
        isValidating: Bool = false
    ) {
        self.requiredChallenges = requiredChallenges
        self.completedChallenges = completedChallenges
        self.isValidating = isValidating
    }

    /// Check if all required challenges have been completed
    public var allChallengesCompleted: Bool {
        // If no challenges required, considered complete
        guard !requiredChallenges.isEmpty else { return true }

        // Check that every required challenge is in the completed set
        return requiredChallenges.allSatisfy { challenge in
            completedChallenges.contains(challenge)
        }
    }

    /// Get the next challenge that needs to be completed
    public var nextChallenge: Challenges? {
        // Return first challenge that hasn't been completed
        return requiredChallenges.first { challenge in
            !completedChallenges.contains(challenge)
        }
    }

    /// Get progress as a fraction (0.0 to 1.0)
    public var progress: Double {
        guard !requiredChallenges.isEmpty else { return 1.0 }
        return Double(completedChallenges.count) / Double(requiredChallenges.count)
    }
}

/// Use case for determining if an alarm can be stopped.
///
/// This enforces the core business rule that alarms with challenges
/// must have all challenges validated before the stop action is allowed.
public struct StopAlarmAllowed {

    /// Determine if the stop action is allowed for an alarm.
    ///
    /// - Parameter challengeState: The current state of challenge validation
    /// - Returns: True if the alarm can be stopped, false otherwise
    public static func execute(challengeState: ChallengeStackState) -> Bool {
        // Core business rule: Stop is only allowed when all challenges are validated
        return challengeState.allChallengesCompleted
    }

    /// Determine if the stop action is allowed based on alarm configuration.
    ///
    /// This variant is used when we only have the alarm configuration,
    /// not the current validation state.
    ///
    /// - Parameters:
    ///   - alarm: The alarm to check
    ///   - completedChallenges: Set of challenges that have been completed
    /// - Returns: True if the alarm can be stopped, false otherwise
    public static func execute(
        alarm: Alarm,
        completedChallenges: Set<Challenges>
    ) -> Bool {
        let state = ChallengeStackState(
            requiredChallenges: alarm.challengeKind,
            completedChallenges: completedChallenges
        )
        return execute(challengeState: state)
    }

    /// Get a human-readable reason why stop is not allowed.
    ///
    /// - Parameter challengeState: The current state of challenge validation
    /// - Returns: Reason string if stop is not allowed, nil if stop is allowed
    public static func reasonForDenial(challengeState: ChallengeStackState) -> String? {
        // If stop is allowed, no reason for denial
        guard !execute(challengeState: challengeState) else { return nil }

        // If currently validating, indicate that
        if challengeState.isValidating {
            return "Challenge validation in progress"
        }

        // If no challenges completed yet
        if challengeState.completedChallenges.isEmpty {
            return "Complete all challenges to stop the alarm"
        }

        // Some challenges completed but not all
        if let nextChallenge = challengeState.nextChallenge {
            return "Complete \(nextChallenge.displayName) challenge to continue"
        }

        // Generic message
        let remaining = challengeState.requiredChallenges.count - challengeState.completedChallenges.count
        return "Complete \(remaining) more challenge(s) to stop the alarm"
    }

    /// Calculate the minimum time before stop could be allowed.
    ///
    /// This is useful for UI hints about when the stop button might become available.
    ///
    /// - Parameters:
    ///   - challengeState: The current state of challenge validation
    ///   - estimatedTimePerChallenge: Estimated seconds per challenge (default 10)
    /// - Returns: Estimated seconds until stop could be allowed, or nil if already allowed
    public static func estimatedTimeUntilAllowed(
        challengeState: ChallengeStackState,
        estimatedTimePerChallenge: TimeInterval = 10
    ) -> TimeInterval? {
        // If already allowed, no wait time
        guard !execute(challengeState: challengeState) else { return nil }

        // Calculate remaining challenges
        let remainingCount = challengeState.requiredChallenges.count - challengeState.completedChallenges.count

        // Estimate time based on remaining challenges
        return TimeInterval(remainingCount) * estimatedTimePerChallenge
    }
}

// MARK: - Challenge Progress Tracking

/// Helper to track challenge completion progress.
public struct ChallengeProgress {
    public let total: Int
    public let completed: Int

    public init(state: ChallengeStackState) {
        self.total = state.requiredChallenges.count
        self.completed = state.completedChallenges.count
    }

    public var remaining: Int {
        return total - completed
    }

    public var percentComplete: Int {
        guard total > 0 else { return 100 }
        return (completed * 100) / total
    }

    public var isComplete: Bool {
        return completed >= total
    }

    public var displayText: String {
        if isComplete {
            return "All challenges completed"
        } else if completed == 0 {
            return "\(total) challenge\(total == 1 ? "" : "s") to complete"
        } else {
            return "\(completed) of \(total) challenges completed"
        }
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/AlarmScheduling+Defaults.swift

```swift
//
//  AlarmScheduling+Defaults.swift
//  alarmAppNew
//
//  Default implementations for AlarmScheduling protocol methods.
//  These allow legacy implementations to adopt the protocol without
//  immediately implementing all new methods.
//

import Foundation

/// Default implementations for backward compatibility.
///
/// These defaults allow the legacy NotificationService to compile
/// without modification while we transition to the full AlarmScheduling protocol.
public extension AlarmScheduling {

    /// Default no-op implementation for authorization.
    /// Legacy implementations may already handle this differently.
    func requestAuthorizationIfNeeded() async throws {
        // No-op default: Legacy implementations handle auth their own way
    }

    /// Default implementation returns a UUID string for compatibility.
    /// Legacy implementations should override this.
    func schedule(alarm: Alarm) async throws -> String {
        // Default: return alarm ID as external identifier
        // Concrete implementations should override this
        return alarm.id.uuidString
    }

    /// Default no-op implementation for stop.
    /// AlarmKit implementations will override this with actual stop behavior.
    func stop(alarmId: UUID) async throws {
        // No-op default: Legacy systems don't have explicit stop
        // AlarmKit adapter will provide real implementation
    }

    /// Default no-op implementation for countdown transition.
    /// AlarmKit implementations will use native countdown; legacy may reschedule.
    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        // No-op default: Legacy systems handle snooze differently
        // AlarmKit adapter will provide real countdown implementation
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Models/Challenges.swift

```swift
//
//  Challenges.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//
public enum Challenges: CaseIterable, Codable, Equatable, Hashable {
  case qr
  case stepCount
  case math

  public var displayName: String {
    switch self {
    case .qr: return "QR Code"
    case .stepCount: return "Step Count"
    case .math: return "Math"
    }
  }

  var iconName: String {
    switch self {
    case .qr: return "qrcode"
    case .stepCount: return "figure.walk"
    case .math: return "function"
    }
  }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/RefreshCoordinator.swift

```swift
//
//  RefreshCoordinator.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/7/25.
//  Coordinates and coalesces notification refresh requests
//

import Foundation

/// Actor that coordinates notification refresh requests to prevent duplicate operations
public actor RefreshCoordinator {
    private var currentRefreshTask: Task<Void, Never>?
    private var isSchedulingInProgress = false
    private let notificationService: AlarmScheduling

    init(notificationService: AlarmScheduling) {
        self.notificationService = notificationService
    }

    /// Request a refresh of all alarms' notifications
    /// If a refresh is already in progress, this will join that operation
    /// rather than starting a duplicate
    public func requestRefresh(alarms: [Alarm]) async {
        // If there's an existing refresh in progress, join it
        if let existingTask = currentRefreshTask,
           !existingTask.isCancelled {
            // Wait for the existing refresh to complete
            await existingTask.value
            return
        }

        // Start a new refresh task using Task.detached to escape view lifecycle
        // This ensures scheduling continues even if the view that triggered it is dismissed
        currentRefreshTask = Task.detached { [weak self] in
            guard let self = self else { return }

            // Mark scheduling as in progress
            await self.setSchedulingInProgress(true)
            defer {
                Task { [weak self] in
                    await self?.setSchedulingInProgress(false)
                }
            }

            // No artificial delay - we coalesce by joining in-flight tasks
            // This will now run independently of any view lifecycle
            await self.notificationService.refreshAll(from: alarms)
        }

        // Wait for completion
        await currentRefreshTask?.value
    }

    /// Check if scheduling is currently in progress
    public func isSchedulingActive() async -> Bool {
        return isSchedulingInProgress
    }

    private func setSchedulingInProgress(_ value: Bool) {
        isSchedulingInProgress = value
    }

    /// Cancel any in-progress refresh operation
    public func cancelCurrentRefresh() {
        currentRefreshTask?.cancel()
        currentRefreshTask = nil
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Types/NotificationType.swift

```swift
//
//  NotificationType.swift
//  alarmAppNew
//
//  Pure Domain type for notification categories.
//  Unified definition to avoid duplication across the codebase.
//

import Foundation

/// Type-safe notification type enumeration
public enum NotificationType: String, CaseIterable, Equatable {
    case main = "main"
    case preAlarm = "pre_alarm"
    case nudge1 = "nudge_1"
    case nudge2 = "nudge_2"
    case nudge3 = "nudge_3"

    /// All nudge notification types
    public static var allNudges: [NotificationType] {
        return [.nudge1, .nudge2, .nudge3]
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/SystemVolumeProviding.swift

```swift
//
//  SystemVolumeProviding.swift
//  alarmAppNew
//
//  Domain protocol for system volume operations.
//  Pure protocol definition with no platform dependencies.
//

import Foundation

/// Protocol for accessing system volume information
public protocol SystemVolumeProviding {
    /// Returns the current media volume (0.0–1.0)
    /// Note: This reads media volume only. Ringer volume is not accessible via public APIs.
    func currentMediaVolume() -> Float
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/SystemVolumeProvider.swift

```swift
//
//  SystemVolumeProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Infrastructure adapter for reading system volume levels
//

import AVFoundation
import alarmAppNew

/// Concrete implementation using AVAudioSession
/// Conforms to the SystemVolumeProviding protocol defined in Domain
@MainActor
final class SystemVolumeProvider: SystemVolumeProviding {
    func currentMediaVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/AudioUXPolicy.swift

```swift
//
//  AudioUXPolicy.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Pure Swift policy constants for audio UX behavior
//

import Foundation

// Pure Swift policy constants
public enum AudioUXPolicy {
    /// Lead time in seconds before test notification fires
    public static let testLeadSeconds: TimeInterval = 8

    /// Threshold for low media volume warning (0.0–1.0)
    public static let lowMediaVolumeThreshold: Float = 0.25

    /// Educational copy explaining ringer vs media volume
    public static let educationCopy = """
        Lock-screen alarms use ringer volume (Settings → Sounds). \
        Foreground alarms use media volume.
        """
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/AppIntents/OpenForChallengeIntent.swift

```swift
//
//  OpenForChallengeIntent.swift
//  alarmAppNew
//
//  App Intent for AlarmKit integration (iOS 26+).
//  Pure payload handoff to app group - no routing, no DI, no singletons.
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
struct OpenForChallengeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open for Challenge"
    static var description = IntentDescription("Opens the app to show alarm challenge dismissal flow")

    // When true, the app will open when this intent runs
    static var openAppWhenRun: Bool = true

    // Parameter for the alarm ID to be handled
    @Parameter(title: "Alarm ID")
    var alarmID: String

    // App group identifier for shared data
    private static let appGroupIdentifier = "group.com.beshoy.alarmAppNew"

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        // Pure data handoff to app group
        guard let sharedDefaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
            // Silently fail if app group is not configured
            // The app will not receive the intent, but that's expected in dev/test
            return .result()
        }

        // Write alarm ID and timestamp to shared defaults
        sharedDefaults.set(alarmID, forKey: "pendingAlarmIntent")
        sharedDefaults.set(Date(), forKey: "pendingAlarmIntentTimestamp")

        // Return success - routing happens in the main app
        return .result()
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Notification+Names.swift

```swift
//
//  Notification+Names.swift
//  alarmAppNew
//
//  Extension for custom notification names used in the app.
//

import Foundation

extension Notification.Name {
    /// Posted when an alarm intent is received from the app group
    static let alarmIntentReceived = Notification.Name("alarmIntentReceived")
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Models/Alarm.swift

```swift
//
//  Untitled.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

import Foundation

public struct Alarm: Codable, Equatable, Hashable, Identifiable {
  public let id: UUID
  var time: Date
  var label: String
  var repeatDays: [Weekdays]
  var challengeKind: [Challenges]
  var expectedQR: String?
  var stepThreshold: Int?
  var mathChallenge: MathChallenge?
  var isEnabled: Bool
  var soundId: String     // Stable sound ID for catalog lookup
  var soundName: String?  // Legacy field - kept for backward compatibility
  var volume: Double      // Volume for in-app ringing and previews only (0.0-1.0)
  public var externalAlarmId: String? // AlarmKit/system identifier

  // MARK: - Coding Keys (CRITICAL for proper encoding/decoding)
  private enum CodingKeys: String, CodingKey {
    case id, time, label, repeatDays, challengeKind
    case expectedQR, stepThreshold, mathChallenge
    case isEnabled, volume
    case soundId    // CRITICAL: Must be in CodingKeys for proper encoding
    case soundName  // Keep for backward compatibility
    case externalAlarmId  // AlarmKit external identifier
  }

  // MARK: - Custom Decoder (handles missing soundId from old JSON)
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode all existing fields
    id = try container.decode(UUID.self, forKey: .id)
    time = try container.decode(Date.self, forKey: .time)
    label = try container.decode(String.self, forKey: .label)
    repeatDays = try container.decode([Weekdays].self, forKey: .repeatDays)
    challengeKind = try container.decode([Challenges].self, forKey: .challengeKind)
    expectedQR = try container.decodeIfPresent(String.self, forKey: .expectedQR)
    stepThreshold = try container.decodeIfPresent(Int.self, forKey: .stepThreshold)
    mathChallenge = try container.decodeIfPresent(MathChallenge.self, forKey: .mathChallenge)
    isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    volume = try container.decode(Double.self, forKey: .volume)

    // Handle missing soundId gracefully (for old persisted alarms)
    soundId = try container.decodeIfPresent(String.self, forKey: .soundId) ?? "ringtone1"

    // Keep legacy soundName for backward compatibility
    soundName = try container.decodeIfPresent(String.self, forKey: .soundName)

    // Handle optional externalAlarmId for AlarmKit integration
    externalAlarmId = try container.decodeIfPresent(String.self, forKey: .externalAlarmId)
  }

  // Standard initializer for new alarms
  init(id: UUID, time: Date, label: String, repeatDays: [Weekdays], challengeKind: [Challenges],
       expectedQR: String? = nil, stepThreshold: Int? = nil, mathChallenge: MathChallenge? = nil,
       isEnabled: Bool, soundId: String, soundName: String? = nil, volume: Double,
       externalAlarmId: String? = nil) {
    self.id = id
    self.time = time
    self.label = label
    self.repeatDays = repeatDays
    self.challengeKind = challengeKind
    self.expectedQR = expectedQR
    self.stepThreshold = stepThreshold
    self.mathChallenge = mathChallenge
    self.isEnabled = isEnabled
    self.soundId = soundId
    self.soundName = soundName
    self.volume = volume
    self.externalAlarmId = externalAlarmId
  }
}

extension Alarm {
  @available(*, unavailable, message: "Use AlarmFactory.makeNewAlarm() instead")
  static var blank: Alarm {
    // This will cause a compile-time error, preventing runtime crashes
    fatalError("Alarm.blank is deprecated - use AlarmFactory.makeNewAlarm() instead")
  }

  // Add this computed property for display purposes
  var repeatDaysText: String {
    guard !repeatDays.isEmpty else { return "" }

    // Check for common patterns
    if repeatDays.count == 7 {
      return "Every day"
    } else if Set(repeatDays) == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) {
      return "Weekdays"
    } else if Set(repeatDays) == Set([.saturday, .sunday]) {
      return "Weekends"
    } else {
      // Sort days by their natural week order and return abbreviated names
      let sortedDays = repeatDays.sorted { $0.rawValue < $1.rawValue }
      return sortedDays.map { $0.displayName }.joined(separator: ", ")
    }
  }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Extensions/Alarm+ExternalId.swift

```swift
//
//  Alarm+ExternalId.swift
//  alarmAppNew
//
//  Extension for managing AlarmKit external identifiers.
//

import Foundation

public extension Alarm {
    /// Returns a copy of the alarm with the specified external ID
    func withExternalId(_ id: String?) -> Alarm {
        var copy = self
        copy.externalAlarmId = id
        return copy
    }

    /// Checks if this alarm has an external ID assigned
    var hasExternalId: Bool {
        externalAlarmId != nil
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/ReliabilityLogger.swift

```swift
//
//  ReliabilityLogger.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/7/25.
//  Local reliability logging for MVP1 critical events
//

import Foundation

// MARK: - Reliability Events
enum ReliabilityEvent: String, Codable {
    case scheduled = "scheduled"
    case fired = "fired"
    case dismissSuccessQR = "dismiss_success_qr"
    case dismissFailQR = "dismiss_fail_qr"
    case dismissSuccess = "dismiss_success"  // Generic success
    case stopFailed = "stop_failed"  // AlarmKit stop failed
    case snoozeSet = "snooze_set"  // Snooze scheduled
    case snoozeFailed = "snooze_failed"  // Snooze scheduling failed
    case notificationsStatusChanged = "notifications_status_changed"
    case cameraPermissionChanged = "camera_permission_changed"
    case alarmRunCreated = "alarm_run_created"
    case alarmRunCompleted = "alarm_run_completed"
}

// MARK: - Log Entry
struct ReliabilityLogEntry: Codable {
    let id: UUID
    let timestamp: Date
    let event: ReliabilityEvent
    let alarmId: UUID?
    let details: [String: String]
    
    init(event: ReliabilityEvent, alarmId: UUID? = nil, details: [String: String] = [:]) {
        self.id = UUID()
        self.timestamp = Date()
        self.event = event
        self.alarmId = alarmId
        self.details = details
    }
}

// MARK: - Reliability Logger Protocol
protocol ReliabilityLogging {
    func log(_ event: ReliabilityEvent, alarmId: UUID?, details: [String: String])
    func exportLogs() -> String
    func clearLogs()
    func getRecentLogs(limit: Int) -> [ReliabilityLogEntry]
}

// MARK: - Local File Reliability Logger
class LocalReliabilityLogger: ReliabilityLogging {
    private let fileManager = FileManager.default
    private let logFileName = "reliability_log.json"
    private let queue = DispatchQueue(label: "reliability-logger", qos: .utility)

    // State management
    private var didActivate = false
    private var cachedRecentLogs: [ReliabilityLogEntry] = []
    private var isCacheValid = false

    private var logFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(logFileName)
    }

    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Explicit activation to ensure directory exists with proper file protection
    func activate() {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.sync {
            guard !didActivate else { return }

            do {
                try ensureDirectoryExistsInternal()
                didActivate = true
                print("ReliabilityLogger: Activated with directory and file protection")
            } catch {
                print("ReliabilityLogger: Activation failed: \(error)")
            }
        }
    }

    func log(_ event: ReliabilityEvent, alarmId: UUID? = nil, details: [String: String] = [:]) {
        dispatchPrecondition(condition: .notOnQueue(queue))

        let entry = ReliabilityLogEntry(event: event, alarmId: alarmId, details: details)

        // Fire-and-forget write with cache invalidation
        queue.async { [weak self] in
            guard let self = self else { return }
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            self.appendLogEntryInternal(entry)

            // Invalidate cache so UI gets fresh data
            self.isCacheValid = false
        }

        // Also print to console for debugging (immediate, not queued)
        print("ReliabilityLog: \(event.rawValue) - \(alarmId?.uuidString.prefix(8) ?? "N/A") - \(details)")
    }

    func exportLogs() -> String {
        dispatchPrecondition(condition: .notOnQueue(queue))

        return queue.sync {
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            do {
                let logs = try loadLogsInternal()
                let jsonData = try jsonEncoder.encode(logs)
                return String(data: jsonData, encoding: .utf8) ?? "Failed to encode logs"
            } catch {
                print("ReliabilityLogger: Export failed: \(error)")
                return "Failed to export logs: \(error.localizedDescription)"
            }
        }
    }

    func clearLogs() {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.async { [weak self] in
            guard let self = self else { return }
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            do {
                if self.fileManager.fileExists(atPath: self.logFileURL.path) {
                    try self.fileManager.removeItem(at: self.logFileURL)
                }
                // Clear cache after successful clear
                self.cachedRecentLogs = []
                self.isCacheValid = true
            } catch {
                print("Failed to clear reliability logs: \(error)")
            }
        }
    }

    func getRecentLogs(limit: Int = 100) -> [ReliabilityLogEntry] {
        dispatchPrecondition(condition: .notOnQueue(queue))

        return queue.sync {
            // Fast path: return cached data if valid
            if isCacheValid && cachedRecentLogs.count >= limit {
                return Array(cachedRecentLogs.suffix(limit))
            }

            // Slow path: load from disk and update cache
            do {
                let logs = try loadLogsInternal()
                cachedRecentLogs = logs
                isCacheValid = true
                return Array(logs.suffix(limit))
            } catch {
                print("Failed to load recent logs: \(error)")
                return []
            }
        }
    }

    // MARK: - Private Methods

    /// Ensure parent directory exists and has proper file protection for lock screen access
    /// INTERNAL: Call only from within queue context to avoid re-entrancy
    private func ensureDirectoryExistsInternal() throws {
        guard !didActivate else { return }

        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        if !fileManager.fileExists(atPath: documentsPath.path) {
            try fileManager.createDirectory(at: documentsPath, withIntermediateDirectories: true, attributes: [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ])
            print("ReliabilityLogger: Created documents directory with file protection")
        }
    }

    /// INTERNAL: Load logs from disk - call only from within queue context
    private func loadLogsInternal() throws -> [ReliabilityLogEntry] {
        guard fileManager.fileExists(atPath: logFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: logFileURL)
        return try jsonDecoder.decode([ReliabilityLogEntry].self, from: data)
    }

    /// INTERNAL: Append log entry - call only from within queue context
    private func appendLogEntryInternal(_ entry: ReliabilityLogEntry) {
        do {
            // Ensure directory exists with proper file protection (if not already done)
            if !didActivate {
                try ensureDirectoryExistsInternal()
            }

            var logs: [ReliabilityLogEntry] = []

            // Safely load existing logs
            do {
                logs = try loadLogsInternal()
            } catch {
                print("ReliabilityLogger: Could not load existing logs, starting fresh: \(error)")
                // Clear corrupted file and start fresh
                try? fileManager.removeItem(at: logFileURL)
                logs = []
            }

            logs.append(entry)

            // Keep only last 1000 entries to prevent excessive file growth
            if logs.count > 1000 {
                logs = Array(logs.suffix(1000))
            }

            // Use atomic write to prevent corruption with consistent encoding
            let jsonData = try jsonEncoder.encode(logs)

            // Write to temporary file first, then move to final location (atomic)
            let tempURL = logFileURL.appendingPathExtension("tmp")

            // Write with proper file protection for lock screen access
            try jsonData.write(to: tempURL, options: [.atomic])

            // Set file protection on temp file before moving
            try fileManager.setAttributes([
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ], ofItemAtPath: tempURL.path)

            // Atomic swap using replaceItem
            if fileManager.fileExists(atPath: logFileURL.path) {
                _ = try fileManager.replaceItem(at: logFileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            } else {
                // First time - just move the temp file
                try fileManager.moveItem(at: tempURL, to: logFileURL)
            }

            // Re-apply file protection after replace (attributes don't always carry over)
            try fileManager.setAttributes([
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ], ofItemAtPath: logFileURL.path)

        } catch {
            print("Failed to append reliability log entry: \(error)")

            // Clean up temp file if it exists
            let tempURL = logFileURL.appendingPathExtension("tmp")
            try? fileManager.removeItem(at: tempURL)

            // Last resort: try to clear the corrupted file
            if error.localizedDescription.contains("JSON") || error.localizedDescription.contains("dataCorrupted") {
                print("ReliabilityLogger: Clearing corrupted log file")
                try? fileManager.removeItem(at: logFileURL)
            }
        }
    }
}

// MARK: - Convenience Extensions
extension ReliabilityLogging {
    func logAlarmScheduled(_ alarmId: UUID, details: [String: String] = [:]) {
        log(.scheduled, alarmId: alarmId, details: details)
    }
    
    func logAlarmFired(_ alarmId: UUID, details: [String: String] = [:]) {
        log(.fired, alarmId: alarmId, details: details)
    }
    
    func logDismissSuccess(_ alarmId: UUID, method: String = "qr", details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["method"] = method
        log(.dismissSuccessQR, alarmId: alarmId, details: enrichedDetails)
    }
    
    func logDismissFail(_ alarmId: UUID, reason: String, details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["reason"] = reason
        log(.dismissFailQR, alarmId: alarmId, details: enrichedDetails)
    }
    
    func logPermissionChange(_ permission: String, status: String, details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["permission"] = permission
        enrichedDetails["status"] = status
        log(.notificationsStatusChanged, alarmId: nil, details: enrichedDetails)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Services/AlarmPresentationBuilder.swift

```swift
//
//  AlarmPresentationBuilder.swift
//  alarmAppNew
//
//  Builder for AlarmKit presentation and schedule configurations.
//  Separates presentation logic from scheduling implementation.
//

import Foundation
import AlarmKit
import SwiftUI

// Type disambiguation: separate domain model from AlarmKit framework types
typealias DomainAlarm = Alarm        // Our domain model

@available(iOS 26.0, *)
typealias AKAlarm = AlarmKit.Alarm   // AlarmKit framework type

/// Protocol for building AlarmKit presentation configurations
protocol AlarmPresentationBuilding {
    /// Build schedule configuration from alarm
    @available(iOS 26.0, *)
    func buildSchedule(from alarm: DomainAlarm) throws -> AKAlarm.Schedule

    /// Build presentation configuration for alarm
    @available(iOS 26.0, *)
    func buildPresentation(for alarm: DomainAlarm) throws -> AlarmAttributes<EmptyMetadata>
}

/// Empty metadata struct conforming to AlarmMetadata
@available(iOS 26.0, *)
struct EmptyMetadata: AlarmMetadata {
    static var defaultValue: EmptyMetadata { EmptyMetadata() }
}

/// Default implementation of presentation builder
struct AlarmPresentationBuilder: AlarmPresentationBuilding {

    enum BuilderError: Error {
        case invalidTime
        case invalidConfiguration
    }

    /// Map domain Weekdays enum to Locale.Weekday (locale-safe)
    @available(iOS 26.0, *)
    private func mapWeekdays(_ days: [Weekdays]) -> [Locale.Weekday] {
        days.map { weekday in
            switch weekday {
            case .sunday: return .sunday
            case .monday: return .monday
            case .tuesday: return .tuesday
            case .wednesday: return .wednesday
            case .thursday: return .thursday
            case .friday: return .friday
            case .saturday: return .saturday
            }
        }
    }

    @available(iOS 26.0, *)
    func buildSchedule(from alarm: DomainAlarm) throws -> AKAlarm.Schedule {
        // Extract time components from alarm
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: alarm.time)

        guard let hour = components.hour, let minute = components.minute else {
            throw BuilderError.invalidTime
        }

        // Create schedule - .fixed() for one-time, .relative() for recurring
        if alarm.repeatDays.isEmpty {
            // One-time alarm at specific date/time
            return .fixed(alarm.time)
        } else {
            // Recurring alarm on specific weekdays
            let time = AKAlarm.Schedule.Relative.Time(hour: hour, minute: minute)
            let recurrence = AKAlarm.Schedule.Relative.Recurrence.weekly(mapWeekdays(alarm.repeatDays))
            let relative = AKAlarm.Schedule.Relative(time: time, repeats: recurrence)
            return .relative(relative)
        }
    }

    @available(iOS 26.0, *)
    func buildPresentation(for alarm: DomainAlarm) throws -> AlarmAttributes<EmptyMetadata> {
        // Wrap title in LocalizedStringResource as required by AlarmKit
        let title = LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? "Alarm" : alarm.label)

        // Create alert presentation with constructed buttons using proper 3-parameter constructor
        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Stop"),
            textColor: .primary,
            systemImageName: "stop.circle"
        )
        let openAppButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Open App"),
            textColor: .accentColor,
            systemImageName: "arrow.up.right.circle"
        )

        let alertContent = AlarmPresentation.Alert(
            title: title,
            stopButton: stopButton,
            secondaryButton: openAppButton,
            secondaryButtonBehavior: .custom
        )

        // Build full presentation (alert only for now - no countdown in alert phase)
        let presentation = AlarmPresentation(alert: alertContent)

        // Create attributes with app's theme color
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: EmptyMetadata.defaultValue,
            tintColor: .blue
        )

        return attributes
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/DismissalFlowView.swift

```swift

import SwiftUI

struct DismissalFlowView: View {
    let alarmID: UUID
    let container: DependencyContainer  // Explicit dependency injection (matches RingingView pattern)
    let onFinish: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSceneReady = false

    var body: some View {
        Group {
            if isSceneReady {
                RingingView(alarmID: alarmID, container: container)
                    .environmentObject(container)  // Inject for child views (ScanningContent, FailedContent)
                    .onDisappear {
                        onFinish()
                    }
            } else {
                // Loading state while scene becomes ready
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .task {
            await ensureSceneReadiness()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active && !isSceneReady {
                Task {
                    await ensureSceneReadiness()
                }
            }
        }
    }
    
    @MainActor
    private func ensureSceneReadiness() async {
        // Wait for scene to be active
        guard scenePhase == .active else { return }
        
        // Short defer to prevent black screens on cold-start
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        isSceneReady = true
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Services/AlarmSchedulerFactory.swift

```swift
//
//  AlarmSchedulerFactory.swift
//  alarmAppNew
//
//  Factory for creating AlarmKit scheduler (iOS 26+ only).
//  Uses explicit dependency injection, not the whole container.
//

import Foundation

/// Factory for creating the AlarmKit scheduler implementation
@MainActor
enum AlarmSchedulerFactory {

    /// Create the AlarmKit scheduler (iOS 26+ only)
    /// - Parameters:
    ///   - presentationBuilder: Builder for AlarmKit presentation configs
    /// - Returns: AlarmKitScheduler instance
    /// - Note: Uses domain UUIDs directly as AlarmKit IDs - no external mapping needed
    @available(iOS 26.0, *)
    static func make(
        presentationBuilder: AlarmPresentationBuilding
    ) -> AlarmScheduling {
        return AlarmKitScheduler(
            presentationBuilder: presentationBuilder
        )
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/AlarmIntentBridge.swift

```swift
//
//  AlarmIntentBridge.swift
//  alarmAppNew
//
//  Bridge for observing and routing alarm intents from app group.
//  No singletons, idempotent operation, clean separation of concerns.
//

import Foundation
import SwiftUI

/// Bridge for handling alarm intents written to app group by OpenForChallengeIntent
@MainActor
final class AlarmIntentBridge: ObservableObject {
    /// Currently pending alarm ID detected from intent
    @Published private(set) var pendingAlarmId: UUID?

    /// App group identifier matching the one used by OpenForChallengeIntent
    private static let appGroupIdentifier = "group.com.beshoy.alarmAppNew"

    /// Shared defaults for reading intent data
    private let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

    /// Keys used for storing intent data
    private enum Keys {
        static let pendingAlarmIntent = "pendingAlarmIntent"
        static let pendingAlarmIntentTimestamp = "pendingAlarmIntentTimestamp"
    }

    /// Maximum age of intent timestamp to consider valid (30 seconds)
    private let maxIntentAge: TimeInterval = 30

    init() {
        // No OS work in initializer - keeps it pure
    }

    /// Check for pending alarm intent in app group and route if valid
    /// This method is idempotent and safe to call repeatedly
    func checkForPendingIntent() {
        guard let sharedDefaults = sharedDefaults else {
            // App group not configured - expected in dev/test
            return
        }

        // Read intent data from app group
        guard let alarmIdString = sharedDefaults.string(forKey: Keys.pendingAlarmIntent),
              let timestamp = sharedDefaults.object(forKey: Keys.pendingAlarmIntentTimestamp) as? Date else {
            // No pending intent
            return
        }

        // Validate timestamp freshness
        let age = abs(timestamp.timeIntervalSinceNow)
        guard age <= maxIntentAge else {
            // Intent is too old - clear it and ignore
            clearPendingIntent()
            print("AlarmIntentBridge: Ignoring stale intent (age: \(Int(age))s)")
            return
        }

        // Parse alarm ID
        guard let alarmId = UUID(uuidString: alarmIdString) else {
            print("AlarmIntentBridge: Invalid alarm ID format: \(alarmIdString)")
            clearPendingIntent()
            return
        }

        // Update published property
        pendingAlarmId = alarmId

        // Clear the intent data (consumed)
        clearPendingIntent()

        // Post notification for routing
        // Pass the intent's alarm ID (which could be pre-migration) as the intent ID
        NotificationCenter.default.post(
            name: .alarmIntentReceived,
            object: nil,
            userInfo: ["intentAlarmId": alarmId]
        )

        print("AlarmIntentBridge: Processing intent for alarm \(alarmId.uuidString.prefix(8))...")
    }

    /// Clear pending intent data from app group
    private func clearPendingIntent() {
        sharedDefaults?.removeObject(forKey: Keys.pendingAlarmIntent)
        sharedDefaults?.removeObject(forKey: Keys.pendingAlarmIntentTimestamp)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/AlarmScheduling.swift

```swift
//
//  AlarmScheduling.swift
//  alarmAppNew
//
//  Domain-level protocol for alarm scheduling operations.
//  This protocol is AlarmKit-agnostic and defines the contract
//  that both legacy (UNNotification) and modern (AlarmKit) implementations must fulfill.
//

import Foundation

/// Domain-level protocol for alarm scheduling operations.
///
/// This protocol unifies scheduling and ringing control, supporting both
/// legacy notification-based alarms and future AlarmKit-based alarms.
///
/// Important: The `stop` method must only be called after challenge validation
/// has been completed successfully. This is enforced at the Presentation layer
/// using the StopAlarmAllowed use case.
public protocol AlarmScheduling {

    /// Request authorization for alarm notifications if not already granted.
    /// This may show system permission dialogs on first call.
    func requestAuthorizationIfNeeded() async throws

    /// Schedule an alarm and return its external identifier.
    /// - Parameter alarm: The alarm to schedule
    /// - Returns: External identifier (e.g., notification ID or AlarmKit ID)
    /// - Throws: If scheduling fails or authorization is denied
    func schedule(alarm: Alarm) async throws -> String

    /// Cancel a scheduled alarm.
    /// - Parameter alarmId: The UUID of the alarm to cancel
    func cancel(alarmId: UUID) async

    /// Get list of currently pending alarm IDs.
    /// - Returns: Array of UUIDs for alarms that are scheduled to fire
    func pendingAlarmIds() async -> [UUID]

    /// Stop a currently ringing alarm.
    ///
    /// IMPORTANT: This method must only be called after all required
    /// challenges have been validated. The Presentation layer must check
    /// StopAlarmAllowed before invoking this method.
    ///
    /// - Parameters:
    ///   - alarmId: The UUID of the alarm to stop
    ///   - intentAlarmId: Optional UUID from the firing intent (for pre-migration alarms)
    /// - Throws: If the alarm cannot be stopped or doesn't exist
    func stop(alarmId: UUID, intentAlarmId: UUID?) async throws

    /// Transition an alarm to countdown/snooze mode.
    ///
    /// This triggers a countdown with the specified duration, after which
    /// the alarm will ring again. On AlarmKit, this uses native countdown.
    /// On legacy systems, this may reschedule the alarm.
    ///
    /// - Parameters:
    ///   - alarmId: The UUID of the alarm to snooze
    ///   - duration: The snooze duration in seconds
    /// - Throws: If the transition fails or alarm doesn't exist
    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws

    /// Reconcile daemon state with persisted alarms (selective, idempotent).
    ///
    /// Uses daemon as source of truth; only schedules missing enabled alarms
    /// and cancels orphaned daemon entries or disabled alarms. Safe to call
    /// during ringing if skipIfRinging is true.
    ///
    /// This method is idempotent and can be called multiple times safely.
    /// It will not cancel and reschedule alarms that are already correctly
    /// scheduled in the daemon.
    ///
    /// - Parameters:
    ///   - alarms: Persisted domain alarms to reconcile against daemon state
    ///   - skipIfRinging: If true, skip reconciliation when alarm is actively alerting
    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/AlarmSchedulingError.swift

```swift
//
//  AlarmSchedulingError.swift
//  alarmAppNew
//
//  Domain-level error protocol for alarm scheduling operations.
//  Keeps Presentation layer fully protocol-typed per CLAUDE.md §1.
//

import Foundation

/// Domain-level errors for alarm scheduling operations.
///
/// This enum provides a clean abstraction over infrastructure-specific errors,
/// allowing the Presentation layer to remain decoupled from concrete
/// implementations like AlarmKitScheduler.
public enum AlarmSchedulingError: Error, Equatable {
    case notAuthorized
    case schedulingFailed
    case alarmNotFound
    case invalidConfiguration
    case systemLimitExceeded
    case permissionDenied
    case ambiguousAlarmState
    case alreadyHandledBySystem  // System auto-dismissed alarm when app foregrounded

    /// Human-readable description for logging and debugging
    public var description: String {
        switch self {
        case .notAuthorized:
            return "AlarmKit authorization not granted"
        case .schedulingFailed:
            return "Failed to schedule alarm"
        case .alarmNotFound:
            return "Alarm not found in system"
        case .invalidConfiguration:
            return "Invalid alarm configuration"
        case .systemLimitExceeded:
            return "System alarm limit exceeded"
        case .permissionDenied:
            return "Permission denied"
        case .ambiguousAlarmState:
            return "Multiple alarms alerting - cannot determine which to stop"
        case .alreadyHandledBySystem:
            return "Alarm was already handled by system (auto-dismissed)"
        }
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Services/AlarmKitScheduler.swift

```swift
//
//  AlarmKitScheduler.swift
//  alarmAppNew
//
//  iOS 26+ AlarmKit implementation of AlarmScheduling protocol.
//  Uses system alarms with native stop/snooze support.
//

import Foundation
import AlarmKit

/// AlarmKit-based implementation for iOS 26+
/// Uses domain UUIDs directly as AlarmKit IDs - no external mapping needed
@available(iOS 26.0, *)
final class AlarmKitScheduler: AlarmScheduling {
    private let presentationBuilder: AlarmPresentationBuilding
    private var hasActivated = false
    private var alarmStateObserver: Task<Void, Never>?

    // Internal error types for AlarmKit operations (private to this implementation)
    private enum InternalError: Error {
        case notAuthorized
        case schedulingFailed
        case alarmNotFound
        case invalidConfiguration
        case systemLimitExceeded
        case permissionDenied
        case ambiguousAlarmState
        case alreadyHandledBySystem
    }

    // Map internal errors to domain-level AlarmSchedulingError
    private func mapToDomainError(_ error: InternalError) -> AlarmSchedulingError {
        switch error {
        case .notAuthorized: return .notAuthorized
        case .schedulingFailed: return .schedulingFailed
        case .alarmNotFound: return .alarmNotFound
        case .invalidConfiguration: return .invalidConfiguration
        case .systemLimitExceeded: return .systemLimitExceeded
        case .permissionDenied: return .permissionDenied
        case .ambiguousAlarmState: return .ambiguousAlarmState
        case .alreadyHandledBySystem: return .alreadyHandledBySystem
        }
    }

    init(presentationBuilder: AlarmPresentationBuilding) {
        self.presentationBuilder = presentationBuilder
        // No OS work in init - activation is explicit
    }

    /// Activate the scheduler (idempotent)
    @MainActor
    func activate() async {
        guard !hasActivated else { return }

        // Observe alarm state changes from AlarmKit
        // AlarmManager.alarmUpdates provides an async sequence of alarm changes
        alarmStateObserver = Task {
            for await updatedAlarms in AlarmManager.shared.alarmUpdates {
                // alarmUpdates yields array of alarms, not single alarm
                for updatedAlarm in updatedAlarms {
                    await handleAlarmStateUpdate(updatedAlarm)
                }
            }
        }

        hasActivated = true
        print("AlarmKitScheduler: Activated with state observation")
    }

    /// One-time migration: reconcile AlarmKit daemon state with domain alarms
    /// Cancels orphaned alarms and schedules missing enabled alarms using domain UUIDs
    @MainActor
    func reconcileAlarmsAfterMigration(persisted: [Alarm]) async {
        let migrationKey = "AlarmKitIDMigrationDone.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("AlarmKitScheduler: Migration already completed")
            return
        }

        print("AlarmKitScheduler: Starting migration reconciliation...")

        // 1) Fetch daemon state (what AlarmKit thinks is scheduled)
        let daemonAlarms: [AlarmKit.Alarm]
        do {
            daemonAlarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Found \(daemonAlarms.count) alarms in daemon")
        } catch {
            print("AlarmKitScheduler: Migration failed to fetch daemon alarms: \(error)")
            return
        }
        let daemonIDs = Set(daemonAlarms.map { $0.id })
        let persistedIDs = Set(persisted.map { $0.id })

        // 2) Cancel stale daemon alarms that aren't in our store (orphans from old mapping)
        let orphans = daemonIDs.subtracting(persistedIDs)
        for orphanID in orphans {
            do {
                try await AlarmManager.shared.cancel(id: orphanID)
                print("AlarmKitScheduler: Cancelled orphan daemon alarm \(orphanID)")
            } catch {
                print("AlarmKitScheduler: Failed to cancel orphan \(orphanID): \(error)")
            }
        }

        // 3) Schedule every enabled domain alarm missing from daemon (using domain UUID)
        for alarm in persisted where alarm.isEnabled {
            if !daemonIDs.contains(alarm.id) {
                do {
                    _ = try await schedule(alarm: alarm)
                    print("AlarmKitScheduler: Scheduled missing alarm \(alarm.id)")
                } catch {
                    print("AlarmKitScheduler: Failed to schedule \(alarm.id): \(error)")
                }
            } else {
                print("AlarmKitScheduler: Alarm \(alarm.id) already in daemon, skipping")
            }
        }

        // 4) Mark migration complete
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("AlarmKitScheduler: Migration completed")
    }

    // MARK: - AlarmScheduling Protocol

    func requestAuthorizationIfNeeded() async throws {
        do {
            try await requestAuthorizationInternally()
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        }
    }

    private func requestAuthorizationInternally() async throws {
        switch AlarmManager.shared.authorizationState {
        case .notDetermined:
            let state = try await AlarmManager.shared.requestAuthorization()
            guard state == .authorized else {
                throw InternalError.notAuthorized
            }
            print("AlarmKitScheduler: Authorization granted")
        case .denied:
            print("AlarmKitScheduler: Authorization denied")
            throw InternalError.notAuthorized
        case .authorized:
            print("AlarmKitScheduler: Already authorized")
        @unknown default:
            throw InternalError.notAuthorized
        }
    }

    func schedule(alarm: Alarm) async throws -> String {
        // Public API: throws domain-level AlarmSchedulingError
        do {
            return try await scheduleInternal(alarm: alarm)
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        } catch {
            // Catch AlarmKit native errors and map to domain error
            print("AlarmKitScheduler: Schedule failed with AlarmKit error: \(error)")
            throw AlarmSchedulingError.schedulingFailed
        }
    }

    private func scheduleInternal(alarm: Alarm) async throws -> String {
        // Build schedule and presentation using our builder
        let schedule = try presentationBuilder.buildSchedule(from: alarm)
        let attributes = try presentationBuilder.buildPresentation(for: alarm)

        // Create AlarmConfiguration using the proper factory method
        // Note: AlarmConfiguration is a nested type under AlarmManager
        let config = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,  // No custom stop intent
            secondaryIntent: OpenForChallengeIntent(alarmID: alarm.id.uuidString),
            sound: .default  // Use default alarm sound
        )

        // Schedule the alarm through AlarmKit using domain UUID directly
        // AlarmKit uses the ID we provide - no separate external ID needed
        let _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: config)

        // Return domain UUID as string (AlarmKit will use this same ID)
        print("AlarmKitScheduler: Scheduled alarm \(alarm.id)")
        return alarm.id.uuidString
    }

    func cancel(alarmId: UUID) async {
        // Use domain UUID directly - AlarmKit uses the same ID we provided in schedule()
        do {
            try await AlarmManager.shared.cancel(id: alarmId)
            print("AlarmKitScheduler: Cancelled alarm \(alarmId)")
        } catch {
            print("AlarmKitScheduler: Error cancelling alarm: \(error)")
        }
    }

    func pendingAlarmIds() async -> [UUID] {
        // Query all alarms from AlarmKit (throwing property, not async)
        do {
            let alarms = try AlarmManager.shared.alarms
            // AlarmKit IDs are the same as our domain UUIDs - direct mapping
            return alarms.map { $0.id }
        } catch {
            print("AlarmKitScheduler: Error fetching alarms: \(error)")
            return []
        }
    }

    func stop(alarmId: UUID, intentAlarmId: UUID? = nil) async throws {
        // Public API: throws domain-level AlarmSchedulingError
        do {
            try stopInternal(alarmId: alarmId, intentAlarmId: intentAlarmId)
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        }
    }

    // MARK: - Private Stop Implementation

    private func stopInternal(alarmId: UUID, intentAlarmId: UUID?) throws {
        // Priority 1: Prefer the ID that actually fired (from OpenForChallengeIntent)
        if let firedId = intentAlarmId {
            do {
                try AlarmManager.shared.stop(id: firedId)
                print("AlarmKitScheduler: Stopped using intent-provided ID: \(firedId)")
                return
            } catch {
                print("AlarmKitScheduler: Intent ID \(firedId) failed with error: \(error)")
            }
        }

        // Priority 2: Post-migration path: domain UUID is the AlarmKit ID
        do {
            try AlarmManager.shared.stop(id: alarmId)
            print("AlarmKitScheduler: Stopped alarm \(alarmId) using domain UUID")
            return
        } catch {
            print("AlarmKitScheduler: Domain UUID \(alarmId) failed with error: \(error)")
        }

        // Priority 3: Scoped fallback - check what alarms exist and their states
        let alarms: [AlarmKit.Alarm]
        do {
            alarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Fallback - found \(alarms.count) alarms in daemon")
            for alarm in alarms {
                print("  - ID: \(alarm.id), State: \(alarm.state)")
            }
        } catch {
            print("AlarmKitScheduler: Failed to fetch alarms for fallback: \(error)")
            throw InternalError.alarmNotFound
        }

        // CRITICAL CHECK: Empty daemon means system auto-dismissed the alarm
        // This happens when app is foregrounded while alarm is alerting
        guard !alarms.isEmpty else {
            print("AlarmKitScheduler: [METRIC] event=alarm_already_handled_by_system alarm_id=\(alarmId) daemon_count=0")
            throw InternalError.alreadyHandledBySystem
        }

        let alerting = alarms.filter { $0.state == .alerting }
        print("AlarmKitScheduler: Found \(alerting.count) alerting alarms")

        guard alerting.count == 1 else {
            if alerting.count > 1 {
                print("AlarmKitScheduler: ERROR - \(alerting.count) alarms alerting, cannot determine which")
                throw InternalError.ambiguousAlarmState
            }
            print("AlarmKitScheduler: No alerting alarms - alarm may have auto-dismissed or timed out")
            throw InternalError.alarmNotFound
        }

        // Exactly one alarm alerting - safe to stop it
        try AlarmManager.shared.stop(id: alerting[0].id)
        print("AlarmKitScheduler: Stopped single alerting alarm \(alerting[0].id) (fallback)")
    }

    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        // Use domain UUID directly - AlarmKit uses the same ID we provided in schedule()
        try AlarmManager.shared.countdown(id: alarmId)
        print("AlarmKitScheduler: Countdown transition initiated for \(alarmId)")
    }

    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async {
        // Check for alerting alarms if skip flag set
        if skipIfRinging {
            do {
                let daemonAlarms = try AlarmManager.shared.alarms
                let hasAlerting = daemonAlarms.contains { $0.state == .alerting }
                if hasAlerting {
                    print("AlarmKitScheduler: Skipping reconcile - alarm is alerting")
                    return
                }
            } catch {
                // Log warning but CONTINUE - better to reconcile than skip entirely
                // Worst case: we reconcile while alarm is ringing (safe - won't cancel it)
                print("AlarmKitScheduler: Warning - couldn't check alerting state: \(error)")
                print("AlarmKitScheduler: Continuing with reconciliation (safe)")
                // Don't return - fall through to reconcile
            }
        }

        // Fetch current daemon state
        let daemonAlarms: [AlarmKit.Alarm]
        do {
            daemonAlarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Reconcile - daemon has \(daemonAlarms.count) alarms")
        } catch {
            print("AlarmKitScheduler: Reconcile failed to fetch daemon: \(error)")
            return
        }

        // Build daemon map by UUID
        let daemonMap = Dictionary(uniqueKeysWithValues: daemonAlarms.map { ($0.id, $0) })

        // For each ENABLED domain alarm: ensure it exists in daemon
        for alarm in alarms where alarm.isEnabled {
            if daemonMap[alarm.id] == nil {
                do {
                    _ = try await schedule(alarm: alarm)
                    print("AlarmKitScheduler: Reconcile - scheduled missing \(alarm.id)")
                } catch {
                    print("AlarmKitScheduler: Reconcile - failed to schedule \(alarm.id): \(error)")
                }
            }
        }

        // For each DISABLED domain alarm: ensure it's NOT in daemon
        for alarm in alarms where !alarm.isEnabled {
            if daemonMap[alarm.id] != nil {
                await cancel(alarmId: alarm.id)
            }
        }

        // Cancel orphans: daemon alarms not in persisted set
        let persistedIDs = Set(alarms.map { $0.id })
        for (daemonID, _) in daemonMap where !persistedIDs.contains(daemonID) {
            await cancel(alarmId: daemonID)
        }

        print("AlarmKitScheduler: Reconcile complete")
    }

    // MARK: - Private Helpers

    private func handleAlarmStateUpdate(_ alarm: AlarmKit.Alarm) async {
        // Sync alarm state with our internal storage
        // Note: Using AlarmKit.Alarm to disambiguate from our domain Alarm type
        // AlarmKit ID is the same as our domain UUID - no mapping needed
        print("AlarmKitScheduler: State update for alarm \(alarm.id): \(alarm.state)")
        // Future: Could notify ViewModels or update local storage here
    }

    deinit {
        // Cancel the observation task when scheduler is deallocated
        alarmStateObserver?.cancel()
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/AlarmRunStoreError.swift

```swift
//
//  AlarmRunStoreError.swift
//  alarmAppNew
//
//  Domain-level error type for AlarmRun persistence operations.
//  Per CLAUDE.md §5.5 error handling strategy and §9 persistence contracts.
//

import Foundation

/// Domain-level errors for AlarmRun persistence operations.
///
/// This enum provides a clean abstraction over infrastructure-specific errors,
/// allowing the Presentation layer to remain decoupled from concrete
/// persistence implementations like AlarmRunStore.
///
/// Per CLAUDE.md §9: All persistence operations must throw typed domain errors.
public enum AlarmRunStoreError: Error, Equatable {
    case saveFailed
    case loadFailed
    case dataCorrupted

    /// Human-readable description for logging and debugging
    public var description: String {
        switch self {
        case .saveFailed:
            return "Failed to save alarm run to persistent storage"
        case .loadFailed:
            return "Failed to load alarm runs from persistent storage"
        case .dataCorrupted:
            return "Alarm run data is corrupted or invalid"
        }
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Persistence/AlarmRunStore.swift

```swift
//
//  AlarmRunStore.swift
//  alarmAppNew
//
//  Thread-safe persistence store for AlarmRun entities.
//  Conforms to CLAUDE.md §3 (actor-based concurrency) and §9 (async persistence).
//

import Foundation

/// Thread-safe actor for managing AlarmRun persistence.
///
/// **Architecture Compliance:**
/// - CLAUDE.md §3: Uses Swift `actor` for shared mutable state (no manual locking)
/// - CLAUDE.md §9: All methods are `async throws` per persistence contract
/// - claude-guardrails.md: No side effects in `init` (only stores UserDefaults reference)
///
/// **Thread Safety:**
/// Actor serialization ensures atomic load-modify-save sequences.
/// Multiple concurrent `appendRun()` calls are automatically serialized.
///
/// **Error Handling:**
/// All methods throw typed `AlarmRunStoreError` per CLAUDE.md §5.5.
actor AlarmRunStore {
    // MARK: - Properties

    private let defaults: UserDefaults
    private let key = "alarm_runs"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Init

    /// Create a new AlarmRunStore.
    ///
    /// - Parameter defaults: UserDefaults instance for persistence (default: .standard)
    ///
    /// **No side effects:** Only stores the UserDefaults reference per claude-guardrails.md.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Append a new alarm run to persistent storage.
    ///
    /// **Thread Safety:** Actor serialization ensures atomic load-append-save.
    ///
    /// - Parameter run: The alarm run to persist
    /// - Throws: `AlarmRunStoreError.loadFailed` if existing runs can't be loaded
    /// - Throws: `AlarmRunStoreError.saveFailed` if encoding or save fails
    func appendRun(_ run: AlarmRun) async throws(AlarmRunStoreError) {
        // Load existing runs (atomic step 1)
        var existingRuns: [AlarmRun] = []
        if let data = defaults.data(forKey: key) {
            do {
                existingRuns = try decoder.decode([AlarmRun].self, from: data)
            } catch {
                // Corruption: log and throw typed error
                print("AlarmRunStore: Failed to decode existing runs: \(error)")
                throw .loadFailed
            }
        }

        // Append new run (atomic step 2)
        existingRuns.append(run)

        // Save back to storage (atomic step 3)
        do {
            let encoded = try encoder.encode(existingRuns)
            defaults.set(encoded, forKey: key)
            defaults.synchronize() // Force immediate write
            print("AlarmRunStore: Appended run \(run.id) for alarm \(run.alarmId) (total: \(existingRuns.count) runs)")
        } catch {
            print("AlarmRunStore: Failed to encode runs: \(error)")
            throw .saveFailed
        }
    }

    /// Load all alarm runs from persistent storage.
    ///
    /// - Returns: Array of all stored alarm runs (empty if none exist)
    /// - Throws: `AlarmRunStoreError.loadFailed` if data exists but can't be decoded
    func loadRuns() async throws(AlarmRunStoreError) -> [AlarmRun] {
        guard let data = defaults.data(forKey: key) else {
            // No data stored yet - not an error, just empty
            return []
        }

        do {
            let runs = try decoder.decode([AlarmRun].self, from: data)
            print("AlarmRunStore: Loaded \(runs.count) runs from storage")
            return runs
        } catch {
            print("AlarmRunStore: Failed to decode runs: \(error)")
            throw .loadFailed
        }
    }

    /// Load alarm runs for a specific alarm.
    ///
    /// - Parameter alarmId: The UUID of the alarm to filter by
    /// - Returns: Array of runs for the specified alarm (empty if none exist)
    /// - Throws: `AlarmRunStoreError.loadFailed` if data can't be loaded
    func runs(for alarmId: UUID) async throws(AlarmRunStoreError) -> [AlarmRun] {
        let allRuns = try await loadRuns()
        let filtered = allRuns.filter { $0.alarmId == alarmId }
        print("AlarmRunStore: Loaded \(filtered.count) runs for alarm \(alarmId)")
        return filtered
    }

    /// Clean up incomplete alarm runs from previous sessions.
    ///
    /// Marks runs older than 1 hour with no `dismissedAt` as failed.
    /// This is called on app launch to handle cases where the app was
    /// killed/crashed during an alarm dismissal flow.
    ///
    /// **Thread Safety:** Actor serialization ensures atomic load-modify-save.
    ///
    /// - Throws: `AlarmRunStoreError.loadFailed` if existing runs can't be loaded
    /// - Throws: `AlarmRunStoreError.saveFailed` if changes can't be saved
    func cleanupIncompleteRuns() async throws(AlarmRunStoreError) {
        // Load all runs (atomic step 1)
        var allRuns = try await loadRuns()
        let now = Date()
        var hasChanges = false

        // Mark stale incomplete runs as failed (atomic step 2)
        for i in 0..<allRuns.count {
            let run = allRuns[i]

            // If run is incomplete (no dismissedAt) and older than 1 hour, mark as failed
            if run.dismissedAt == nil &&
               run.outcome == .failed && // Default state
               now.timeIntervalSince(run.firedAt) > 3600 { // 1 hour

                allRuns[i].outcome = .failed
                hasChanges = true
                print("AlarmRunStore: Marked stale AlarmRun as failed: \(run.id) (alarm: \(run.alarmId))")
            }
        }

        // Save changes if any (atomic step 3)
        if hasChanges {
            do {
                let encoded = try encoder.encode(allRuns)
                defaults.set(encoded, forKey: key)
                defaults.synchronize()
                print("AlarmRunStore: Cleanup complete - marked \(allRuns.count) runs")
            } catch {
                print("AlarmRunStore: Failed to save after cleanup: \(error)")
                throw .saveFailed
            }
        } else {
            print("AlarmRunStore: Cleanup complete - no changes needed")
        }
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/alarmAppNewApp.swift

```swift
//
//  alarmAppNewApp.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//


import SwiftUI
import UserNotifications

@main
struct alarmAppNewApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // OWNED instance - no singleton
    private let dependencyContainer = DependencyContainer()

    init() {
        // CRITICAL: Activate AlarmKit scheduler at app launch (iOS 26+ only)
        setupAlarmKit()

        // Activate observability systems for production-ready logging
        dependencyContainer.activateObservability()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()              // we'll repurpose ContentView as the Root
                .environmentObject(dependencyContainer.appRouter)
                .environment(\.container, dependencyContainer)  // Inject via environment
                // Check for pending intents when app becomes active
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task { @MainActor in
                        dependencyContainer.alarmIntentBridge.checkForPendingIntent()
                    }
                }
                // Route to ringing screen when alarm intent is received
                .onReceive(NotificationCenter.default.publisher(for: .alarmIntentReceived)) { notification in
                    if let intentAlarmId = notification.userInfo?["intentAlarmId"] as? UUID {
                        // For post-migration alarms, intent ID == domain UUID
                        // For pre-migration alarms, we pass intent ID and use fallback in stop()
                        // Since we can't determine which is which here, pass intent ID as both
                        dependencyContainer.appRouter.showRinging(for: intentAlarmId, intentAlarmID: intentAlarmId)
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func setupAlarmKit() {
        // AlarmKit activation and initialization sequence (iOS 26+ only)
        Task {
            do {
                // 1. Activate AlarmKit scheduler (idempotent)
                await dependencyContainer.activateAlarmScheduler()
                print("App Launch: Activated AlarmKit scheduler")

                // 2. ONE-TIME MIGRATION: Reconcile AlarmKit IDs after external mapping removal
                //    This ensures alarms scheduled before the ID mapping fix are re-registered
                //    with their domain UUIDs. Runs once per migration version.
                await dependencyContainer.migrateAlarmKitIDsIfNeeded()
                print("App Launch: Completed AlarmKit ID migration check")

                // 3. Selective reconciliation: sync daemon with domain alarms
                //    Uses daemon as source of truth; only touches mismatched alarms
                let alarms = try await dependencyContainer.persistenceService.loadAlarms()
                await dependencyContainer.alarmScheduler.reconcile(
                    alarms: alarms,
                    skipIfRinging: true
                )
                print("App Launch: Reconciled daemon state")
            } catch {
                print("App Launch: Failed to setup AlarmKit: \(error)")
            }
        }

        print("App Launch: AlarmKit setup initiated")
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active {
            Task {
                // Clean up incomplete alarm runs from previous sessions
                do {
                    try await dependencyContainer.alarmRunStore.cleanupIncompleteRuns()  // NEW: async actor call
                } catch {
                    print("Failed to cleanup incomplete runs: \(error)")
                }

                // Re-register all notifications when app becomes active
                let alarmListVM = dependencyContainer.makeAlarmListViewModel()
                await alarmListVM.refreshAllAlarms()
            }
        }
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Services/GlobalLimitGuard.swift

```swift
//
//  GlobalLimitGuard.swift
//  alarmAppNew
//
//  Thread-safe notification slot reservation using Swift actor model.
//  Conforms to CLAUDE.md §3 (actor-based concurrency) and claude-guardrails.md.
//

import Foundation
import UserNotifications
import os.log

public struct GlobalLimitConfig {
    public let safetyBuffer: Int
    public let maxSystemLimit: Int

    public init(safetyBuffer: Int = 4, maxSystemLimit: Int = 64) {
        self.safetyBuffer = safetyBuffer
        self.maxSystemLimit = maxSystemLimit
    }

    public var availableThreshold: Int {
        return maxSystemLimit - safetyBuffer
    }
}

/// Thread-safe actor for managing global notification slot reservations.
///
/// **Architecture Compliance:**
/// - CLAUDE.md §3: Uses Swift `actor` for shared mutable state (no manual locking)
/// - claude-guardrails.md: Zero usage of DispatchSemaphore or DispatchQueue.sync
///
/// **Thread Safety:**
/// Actor serialization ensures atomic reserve-modify-finalize sequences.
/// Multiple concurrent `reserve()` calls are automatically serialized by Swift.
public actor GlobalLimitGuard {
    private let config: GlobalLimitConfig
    private let notificationCenter: UNUserNotificationCenter
    private let log = OSLog(subsystem: "alarmAppNew", category: "GlobalLimitGuard")

    // Actor-isolated state (no manual locking needed)
    private var reservedSlots = 0

    public init(
        config: GlobalLimitConfig = GlobalLimitConfig(),
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.config = config
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public Interface

    /// Reserve notification slots atomically.
    ///
    /// Actor isolation ensures this method is thread-safe without manual locking.
    /// Multiple concurrent calls are automatically serialized by Swift.
    ///
    /// - Parameter count: Number of slots requested
    /// - Returns: Number of slots actually granted (may be less than requested)
    public func reserve(_ count: Int) async -> Int {
        // Actor isolation ensures this entire sequence is atomic - no manual locking needed
        let available = await computeAvailableSlots()
        let granted = min(count, max(0, available - reservedSlots))

        reservedSlots += granted

        os_log("Reserved %d of %d requested slots (available: %d, reserved: %d)",
               log: log, type: .info, granted, count, available, reservedSlots)

        return granted
    }

    /// Release reserved slots after scheduling completes.
    ///
    /// Actor isolation ensures this method is thread-safe without manual locking.
    ///
    /// - Parameter actualScheduled: Number of slots that were actually used
    public func finalize(_ actualScheduled: Int) async {
        // Actor isolation ensures this is atomic - no manual locking needed
        reservedSlots = max(0, reservedSlots - actualScheduled)

        os_log("Finalized %d scheduled notifications (remaining reserved: %d)",
               log: log, type: .debug, actualScheduled, reservedSlots)
    }

    public func availableSlots() async -> Int {
        return await computeAvailableSlots()
    }

    // MARK: - Private Implementation

    private func computeAvailableSlots() async -> Int {
        do {
            let pendingRequests = await notificationCenter.pendingNotificationRequests()
            let currentPending = pendingRequests.count
            let available = max(0, config.availableThreshold - currentPending)

            os_log("Available slots: %d (pending: %d, threshold: %d, safety buffer: %d)",
                   log: log, type: .debug, available, currentPending,
                   config.availableThreshold, config.safetyBuffer)

            return available
        } catch {
            os_log("Failed to get pending notifications: %@", log: log, type: .error, error.localizedDescription)

            #if DEBUG
            assertionFailure("Failed to get pending notifications: \(error)")
            #endif

            // Conservative fallback: assume we're near the limit
            return 1
        }
    }
}

// MARK: - Test Support

#if DEBUG
extension GlobalLimitGuard {
    /// Get current reserved slots count (async due to actor isolation).
    public var currentReservedSlots: Int {
        get async { reservedSlots }
    }

    /// Reset all reservations (async due to actor isolation).
    public func resetReservations() async {
        reservedSlots = 0
    }
}
#endif```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/Services/ChainedNotificationScheduler.swift

```swift
//
//  ChainedNotificationScheduler.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import UserNotifications
import UIKit
import os.log
import os.signpost

// MARK: - Protocol Definition

public protocol ChainedNotificationScheduling {
    func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome
    func cancelChain(alarmId: UUID) async
    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async
    func getIdentifiers(alarmId: UUID) -> [String]
    func getAllTrackedIdentifiers() -> Set<String>
    func requestAuthorization() async throws
    func cleanupStaleChains() async
}

// MARK: - Implementation

public final class ChainedNotificationScheduler: ChainedNotificationScheduling {
    private let notificationCenter: UNUserNotificationCenter
    private let soundCatalog: SoundCatalogProviding
    private let notificationIndex: NotificationIndexProviding
    private let chainPolicy: ChainPolicy
    private let globalLimitGuard: GlobalLimitGuard
    private let clock: Clock

    private let log = OSLog(subsystem: "alarmAppNew", category: "ChainedNotificationScheduler")
    private let signpostLog = OSLog(subsystem: "alarmAppNew", category: "ChainScheduling")

    public init(
        notificationCenter: UNUserNotificationCenter = .current(),
        soundCatalog: SoundCatalogProviding,
        notificationIndex: NotificationIndexProviding,
        chainPolicy: ChainPolicy,
        globalLimitGuard: GlobalLimitGuard = GlobalLimitGuard(),
        clock: Clock = SystemClock()
    ) {
        self.notificationCenter = notificationCenter
        self.soundCatalog = soundCatalog
        self.notificationIndex = notificationIndex
        self.chainPolicy = chainPolicy
        self.globalLimitGuard = globalLimitGuard
        self.clock = clock
    }

    // MARK: - Public Interface

    public func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "ScheduleBatch",
                   signpostID: signpostID, "alarmId=%@", alarm.id.uuidString)
        defer {
            os_signpost(.end, log: signpostLog, name: "ScheduleBatch", signpostID: signpostID)
        }

        // Step 1: Compute anchor and base interval (use single clock reading)
        let now = clock.now()
        let minLeadTime = TimeInterval(chainPolicy.settings.minLeadTimeSec)
        let anchor = fireDate  // Domain-determined alarm time (must be strictly future)

        // ANCHOR INTEGRITY: Log received anchor for comparison with Domain
        os_log("SCHED received_anchor: %@ for alarm %@",
               log: log, type: .info,
               anchor.ISO8601Format(), alarm.id.uuidString.prefix(8).description)

        // Guard: Domain should never give us a past anchor
        guard anchor > now else {
            os_log("ANCHOR_PAST_GUARD: Domain gave past anchor for alarm %@: anchor=%@ now=%@",
                   log: log, type: .error, alarm.id.uuidString,
                   anchor.ISO8601Format(), now.ISO8601Format())
            return .unavailable(reason: .invalidConfiguration)
        }

        // Calculate interval respecting both domain decision and lead time
        let deltaFromNow = anchor.timeIntervalSince(now)
        // Use ceil to avoid pre-anchor fires, then apply minimum constraints
        let baseInterval = max(ceil(deltaFromNow), minLeadTime, 1.0)  // ceil prevents early fire, 1.0 is iOS minimum

        // Log the timing calculation for debugging
        os_log("Chain timing for alarm %@: anchor=%@ now=%@ delta=%.1fs leadTime=%.1fs baseInterval=%.1fs",
               log: log, type: .info, alarm.id.uuidString,
               anchor.ISO8601Format(), now.ISO8601Format(), deltaFromNow, minLeadTime, baseInterval)

        // Step 2: Check permissions
        let authStatus = await notificationCenter.notificationSettings().authorizationStatus
        guard authStatus == .authorized else {
            os_log("Notifications not authorized (status: %@) for alarm %@",
                   log: log, type: .error, String(describing: authStatus), alarm.id.uuidString)
            return .unavailable(reason: .permissions)
        }

        // Step 3: Compute chain with aggressive spacing
        // Use fallback spacing for all alarms (aggressive wake-up mode)
        // Sound duration is irrelevant for notification timing - we want rapid alerts
        let spacingSeconds = TimeInterval(chainPolicy.settings.fallbackSpacingSec)
        let chainConfig = chainPolicy.computeChain(spacingSeconds: Int(spacingSeconds))

        let soundInfo = soundCatalog.safeInfo(for: alarm.soundId)

        os_log("Chain config for alarm %@: spacing=%.0fs count=%d (sound: %@)",
               log: log, type: .info, alarm.id.uuidString, spacingSeconds,
               chainConfig.chainCount, soundInfo?.name ?? "fallback")

        // Step 4: Reserve slots atomically
        guard let reservedCount = await reserveSlots(requestedCount: chainConfig.chainCount),
              reservedCount > 0 else {
            os_log("No available slots for alarm %@ (requested: %d)",
                   log: log, type: .error, alarm.id.uuidString, chainConfig.chainCount)
            #if DEBUG
            print("🔍 [DIAG] Reservation FAILED: requested=\(chainConfig.chainCount) granted=0")
            #endif
            return .unavailable(reason: .globalLimit)
        }

        #if DEBUG
        print("🔍 [DIAG] Reservation SUCCESS: requested=\(chainConfig.chainCount) granted=\(reservedCount)")
        #endif

        defer {
            // Finalize is now async (actor method), must wrap in Task
            Task { await globalLimitGuard.finalize(reservedCount) }
        }

        // Step 5: Compute final chain configuration
        let finalConfig = chainConfig.trimmed(to: reservedCount)

        // Step 6: Cancel existing chain and schedule new one
        let outcome = await performIdempotentReschedule(
            alarm: alarm,
            anchor: anchor,
            start: anchor,  // Use anchor as start - domain has decided the time
            baseInterval: baseInterval,
            spacing: spacingSeconds,
            chainCount: finalConfig.chainCount,
            originalCount: chainConfig.chainCount
        )

        // Log the final outcome
        logScheduleOutcome(outcome, alarm: alarm, fireDate: fireDate)

        return outcome
    }

    public func cancelChain(alarmId: UUID) async {
        os_log("Cancelling notification chain for alarm %@", log: log, type: .info, alarmId.uuidString)

        let identifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)

        if !identifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            notificationIndex.clearIdentifiers(alarmId: alarmId)
            notificationIndex.clearChainMeta(alarmId: alarmId)

            os_log("Cancelled %d notifications for alarm %@",
                   log: log, type: .info, identifiers.count, alarmId.uuidString)
        }
    }

    public func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
        os_log("Cancelling occurrence %@ for alarm %@", log: log, type: .info,
               String(occurrenceKey.prefix(10)), alarmId.uuidString)

        let allIdentifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)
        let matchingIdentifiers = allIdentifiers.filter { identifier in
            identifier.contains("-occ-\(occurrenceKey)-")
        }

        if !matchingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingIdentifiers)
            let remainingIdentifiers = allIdentifiers.filter { !matchingIdentifiers.contains($0) }
            notificationIndex.saveIdentifiers(alarmId: alarmId, identifiers: remainingIdentifiers)

            os_log("Cancelled %d occurrence notifications for alarm %@, %d remaining",
                   log: log, type: .info, matchingIdentifiers.count, alarmId.uuidString,
                   remainingIdentifiers.count)
        } else {
            os_log("No matching occurrence notifications found for %@",
                   log: log, type: .info, String(occurrenceKey.prefix(10)))
        }
    }

    public func getIdentifiers(alarmId: UUID) -> [String] {
        return notificationIndex.loadIdentifiers(alarmId: alarmId)
    }

    public func getAllTrackedIdentifiers() -> Set<String> {
        var allIdentifiers = Set<String>()
        let allAlarmIds = notificationIndex.allTrackedAlarmIds()
        for alarmId in allAlarmIds {
            let ids = notificationIndex.loadIdentifiers(alarmId: alarmId)
            allIdentifiers.formUnion(ids)
        }
        return allIdentifiers
    }

    public func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)

            if !granted {
                os_log("Notification authorization denied by user", log: log, type: .error)
                throw NotificationSchedulingError.authorizationDenied
            }

            os_log("Notification authorization granted", log: log, type: .info)
        } catch {
            os_log("Authorization request failed: %@", log: log, type: .error, error.localizedDescription)
            throw error
        }
    }

    public func cleanupStaleChains() async {
        os_log("Starting stale chain cleanup", log: log, type: .info)

        let now = clock.now()
        let allAlarmIds = notificationIndex.allTrackedAlarmIds()
        let gracePeriod = TimeInterval(chainPolicy.settings.cleanupGraceSec)

        var totalStale = 0
        var skippedNoMeta = 0

        for alarmId in allAlarmIds {
            // Load persisted metadata
            guard let meta = notificationIndex.loadChainMeta(alarmId: alarmId) else {
                // No metadata = cannot determine staleness accurately
                // Skip to avoid false positives during migration
                skippedNoMeta += 1
                os_log("Skipping cleanup for alarm %@ (no metadata)",
                       log: log, type: .info, alarmId.uuidString)
                continue
            }

            // Calculate actual chain end using persisted values
            // Last notification fires at: start + (count - 1) * spacing
            let lastFireTime = meta.start.addingTimeInterval(Double(meta.count - 1) * meta.spacing)
            let cleanupTime = lastFireTime.addingTimeInterval(gracePeriod)

            // Only remove if truly stale
            if now > cleanupTime {
                let identifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)

                if !identifiers.isEmpty {
                    notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
                    notificationIndex.removeIdentifiers(alarmId: alarmId, identifiers: identifiers)
                    notificationIndex.clearChainMeta(alarmId: alarmId)
                    totalStale += identifiers.count

                    os_log("Cleaned up %d stale notifications for alarm %@ (start: %@, lastFire: %@, cleanup: %@)",
                           log: log, type: .info, identifiers.count, alarmId.uuidString,
                           meta.start.ISO8601Format(), lastFireTime.ISO8601Format(), cleanupTime.ISO8601Format())
                }
            } else {
                os_log("Chain for alarm %@ not stale yet (cleanup time: %@, now: %@)",
                       log: log, type: .debug, alarmId.uuidString,
                       cleanupTime.ISO8601Format(), now.ISO8601Format())
            }
        }

        if skippedNoMeta > 0 {
            os_log("Skipped %d alarms without metadata during cleanup",
                   log: log, type: .info, skippedNoMeta)
        }

        os_log("Stale chain cleanup complete: removed %d notifications, skipped %d without metadata",
               log: log, type: .info, totalStale, skippedNoMeta)
    }

    // MARK: - Private Implementation

    private func reserveSlots(requestedCount: Int) async -> Int? {
        let granted = await globalLimitGuard.reserve(requestedCount)

        if granted == 0 {
            return nil
        }

        return granted
    }

    private func performIdempotentReschedule(
        alarm: Alarm,
        anchor: Date,
        start: Date,
        baseInterval: TimeInterval,
        spacing: TimeInterval,
        chainCount: Int,
        originalCount: Int
    ) async -> ScheduleOutcome {
        // Generate expected identifiers using anchor (stable identity)
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)
        let expectedIdentifiers = (0..<chainCount).map { index in
            return "alarm-\(alarm.id.uuidString)-occ-\(occurrenceKey)-\(index)"
        }

        // CRITICAL OBSERVABILITY: Log scheduling start
        let now = clock.now()
        let intervals = (0..<chainCount).map { index in
            Int(baseInterval + Double(index) * spacing)
        }
        os_log("SCHED start: alarmId=%@ occurrenceKey=%@ now=%@ anchor=%@ deltaSec=%d intervals=%@",
               log: log, type: .info,
               alarm.id.uuidString.prefix(8).description,
               occurrenceKey,
               now.ISO8601Format(),
               anchor.ISO8601Format(),
               Int(anchor.timeIntervalSince(now)),
               intervals.description)

        var scheduledCount = 0

        // Wrap scheduling in background task to prevent cancellation on app background
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ScheduleAlarm-\(alarm.id.uuidString)") {
            // Expiration handler: clean up if system force-terminates
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }

        // Clear existing identifiers and schedule new ones atomically
        notificationIndex.clearIdentifiers(alarmId: alarm.id)
        scheduledCount = await scheduleNotificationRequests(
            alarm: alarm,
            anchor: anchor,
            identifiers: expectedIdentifiers,
            baseInterval: baseInterval,
            spacing: spacing,
            start: start
        )
        notificationIndex.saveIdentifiers(alarmId: alarm.id, identifiers: expectedIdentifiers)

        // Save chain metadata for accurate cleanup later
        let meta = ChainMeta(
            start: start,  // Use the actual start time that was computed and used for scheduling
            spacing: spacing,
            count: chainCount,
            createdAt: clock.now()
        )
        notificationIndex.saveChainMeta(alarmId: alarm.id, meta: meta)

        // CRITICAL: End background task on all paths (success/failure handled above)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        // Determine outcome type
        if originalCount > chainCount {
            return .trimmed(original: originalCount, scheduled: scheduledCount)
        } else {
            return .scheduled(count: scheduledCount)
        }
    }

    private func scheduleNotificationRequests(
        alarm: Alarm,
        anchor: Date,
        identifiers: [String],
        baseInterval: TimeInterval,
        spacing: TimeInterval,
        start: Date
    ) async -> Int {
        // Idempotent: Remove any existing notifications for this occurrence before adding new ones
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)

        // SERIALIZE: Await removal completion before adding to prevent race conditions
        await withCheckedContinuation { continuation in
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            // Give the system a moment to process the removal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                continuation.resume()
            }
        }

        os_log("Idempotent: Removed existing requests for occurrence %@ (count=%d)",
               log: log, type: .info, occurrenceKey, identifiers.count)

        // Log comprehensive scheduling info
        os_log("Scheduling chain: baseInterval=%.1fs spacing=%.1fs count=%d for alarm %@",
               log: log, type: .info, baseInterval, spacing, identifiers.count, alarm.id.uuidString)

        var successCount = 0

        for (index, identifier) in identifiers.enumerated() {
            // Calculate interval for this notification: base + index * spacing
            let interval = baseInterval + Double(index) * spacing

            do {
                let request = try buildNotificationRequest(
                    alarm: alarm,
                    anchor: anchor,
                    identifier: identifier,
                    occurrence: index,
                    interval: interval,
                    start: start,
                    isFirst: index == 0
                )

                // Add request and log result
                do {
                    try await notificationCenter.add(request)
                    successCount += 1

                    // CRITICAL OBSERVABILITY: Log successful add
                    os_log("SCHED added: id=%@ (notification %d/%d)",
                           log: log, type: .info,
                           identifier, index + 1, identifiers.count)
                } catch {
                    // CRITICAL OBSERVABILITY: Log add error
                    os_log("SCHED add_error: %@ for id=%@",
                           log: log, type: .error,
                           error.localizedDescription, identifier)
                    #if DEBUG
                    assertionFailure("Notification scheduling failed: \(error)")
                    #endif
                }

            } catch {
                os_log("Failed to build notification request %@: %@",
                       log: log, type: .error, identifier, error.localizedDescription)
                #if DEBUG
                assertionFailure("Notification request building failed: \(error)")
                #endif
            }
        }

        // CRITICAL: Immediate post-schedule verification
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let ourPending = pendingRequests.filter { identifiers.contains($0.identifier) }
        let pendingIds = ourPending.map { $0.identifier }

        // CRITICAL OBSERVABILITY: Log post-check
        os_log("SCHED post_check: pendingCount=%d ids=%@",
               log: log, type: .info,
               ourPending.count, pendingIds.description)

        // ASSERT: pendingCount must equal chainLength
        if ourPending.count != identifiers.count {
            os_log("❌ SCHEDULING FAILURE: Expected %d notifications but only %d are pending for alarm %@",
                   log: log, type: .fault,  // Use .fault for critical failures
                   identifiers.count, ourPending.count, alarm.id.uuidString)
        }

        return successCount
    }

    private func buildNotificationRequest(
        alarm: Alarm,
        anchor: Date,
        identifier: String,
        occurrence: Int,
        interval: TimeInterval,
        start: Date,
        isFirst: Bool
    ) throws -> UNNotificationRequest {
        // Build content
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.sound = buildNotificationSound(alarm: alarm) // Use alarm's custom sound from catalog
        content.categoryIdentifier = "ALARM_CATEGORY"

        // Add userInfo with alarmId and occurrenceKey for occurrence-scoped cancellation
        // Use anchor for stable identity (not shifted time)
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "occurrenceKey": occurrenceKey
        ]

        // ALWAYS use interval trigger to avoid calendar race conditions
        // Clamp to iOS minimum (1 second) to ensure future scheduling
        let clampedInterval = max(1.0, interval)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: clampedInterval, repeats: false)

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func buildNotificationSound(alarm: Alarm) -> UNNotificationSound {
        // safeInfo already provides fallback to default sound if ID is invalid
        let soundInfo = soundCatalog.safeInfo(for: alarm.soundId)
        let fileName = soundInfo?.fileName ?? "ringtone1.caf"  // Fallback to actual file name, not "default"
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }

    internal func buildTriggerWithInterval(_ interval: TimeInterval) -> UNNotificationTrigger {
        // Only clamp to iOS minimum (1 second), no per-item min lead time
        let clampedInterval = max(1.0, interval)
        return UNTimeIntervalNotificationTrigger(timeInterval: clampedInterval, repeats: false)
    }

    private func logScheduleOutcome(_ outcome: ScheduleOutcome, alarm: Alarm, fireDate: Date) {
        switch outcome {
        case .scheduled(let count):
            os_log("Successfully scheduled %d notifications for alarm %@ at %@",
                   log: log, type: .info, count, alarm.id.uuidString, fireDate.description)

        case .trimmed(let original, let scheduled):
            os_log("Trimmed chain for alarm %@: %d -> %d notifications (global limit)",
                   log: log, type: .info, alarm.id.uuidString, original, scheduled)

        case .unavailable(let reason):
            let reasonString = String(describing: reason)
            os_log("Failed to schedule notifications for alarm %@: %@",
                   log: log, type: .error, alarm.id.uuidString, reasonString)
        }
    }
}

// MARK: - Error Types

public enum NotificationSchedulingError: Error {
    case authorizationDenied
    case invalidConfiguration
    case systemLimitExceeded
}

extension NotificationSchedulingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification permissions are required to schedule alarms"
        case .invalidConfiguration:
            return "Invalid notification configuration"
        case .systemLimitExceeded:
            return "Too many notifications already scheduled"
        }
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/AlarmScheduling+CompatShims.swift

```swift
//
//  AlarmScheduling+CompatShims.swift
//  alarmAppNew
//
//  Compatibility shims for legacy NotificationScheduling methods.
//  These allow gradual migration from old method names to new AlarmScheduling API.
//  These shims can be removed once all call sites are migrated.
//

import Foundation

/// Compatibility shims for legacy method names.
/// These forward to new AlarmScheduling methods or provide safe no-ops.
public extension AlarmScheduling {

    // MARK: - Core Scheduling Methods

    /// Legacy: Schedule an alarm
    /// Forwards to new `schedule(alarm:)` method
    func scheduleAlarm(_ alarm: Alarm) async throws {
        _ = try await schedule(alarm: alarm)
    }

    /// Legacy: Cancel an alarm
    /// Forwards to new `cancel(alarmId:)` method
    func cancelAlarm(_ alarm: Alarm) async {
        await cancel(alarmId: alarm.id)
    }

    /// Legacy: Refresh all alarms
    /// Now delegates to selective reconciliation for safety
    func refreshAll(from alarms: [Alarm]) async {
        // Delegate to selective reconciliation instead of blind cancel/reschedule
        await reconcile(alarms: alarms, skipIfRinging: true)
    }

    /// Default reconciliation: no-op for implementations that don't need it
    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async {
        // Default no-op for schedulers that don't require reconciliation
    }

    /// Legacy: Schedule alarm immediately
    /// Forwards to regular schedule (immediate scheduling is implementation detail)
    func scheduleAlarmImmediately(_ alarm: Alarm) async throws {
        _ = try await schedule(alarm: alarm)
    }

    // MARK: - Test Alarm Methods

    /// Legacy: Schedule one-off test alarm
    /// Creates a test alarm and schedules it
    func scheduleOneOffTestAlarm(leadTime: TimeInterval = 8) async throws {
        // This is a test-specific method that concrete implementations can override
        // Default implementation creates a simple test alarm
        // Concrete implementations should provide proper test alarm scheduling
    }

    /// Legacy: Schedule test notification with custom sound
    func scheduleTestNotification(soundName: String?, in seconds: TimeInterval) async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with system default sound
    func scheduleTestSystemDefault() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with critical sound
    func scheduleTestCriticalSound() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with custom sound
    func scheduleTestCustomSound(soundName: String?) async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with default settings
    func scheduleTestDefault() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with custom settings
    func scheduleTestCustom() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test
    func scheduleBareDefaultTest() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test without interruption
    func scheduleBareDefaultTestNoInterruption() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test without category
    func scheduleBareDefaultTestNoCategory() async throws {
        // Test-specific method - concrete implementations should override
    }

    // MARK: - Cleanup Methods

    /// Legacy: Cancel specific notification types for an alarm
    func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType]) {
        // This is a detailed implementation concern
        // The new API uses simple cancel(alarmId:) for all types
        // Concrete implementations can override for specific behavior
    }

    /// Legacy: Cancel a specific occurrence of an alarm
    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
        // Occurrence-level cancellation is an implementation detail
        // Default to canceling the entire alarm for safety
        await cancel(alarmId: alarmId)
    }

    /// Legacy: Clean up stale delivered notifications
    func cleanupStaleDeliveredNotifications() async {
        // Cleanup is an implementation detail
        // Concrete implementations can override if needed
    }

    /// Legacy: Clean up after alarm dismissal
    func cleanupAfterDismiss(alarmId: UUID, occurrenceKey: String? = nil) async {
        // Intentionally no-op shim; concrete implementations can override
        // Do not map to cancel to avoid hidden behavior changes
    }

    // MARK: - Configuration Methods

    /// Legacy: Ensure notification categories are registered
    func ensureNotificationCategoriesRegistered() {
        // Category registration is an implementation detail
        // Concrete implementations should handle this internally
    }

    // MARK: - Diagnostic Methods

    /// Legacy: Dump notification settings for debugging
    func dumpNotificationSettings() async {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Validate sound bundle
    func validateSoundBundle() {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Dump notification categories for debugging
    func dumpNotificationCategories() async {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Run complete sound triage
    func runCompleteSoundTriage() async throws {
        // Diagnostic method - concrete implementations can override
    }
}

// MARK: - Additional Helper Methods

public extension AlarmScheduling {
    /// Get notification request IDs for a specific alarm occurrence
    func getRequestIds(alarmId: UUID, occurrenceKey: String) async -> [String] {
        // Default implementation returns empty array
        // Concrete implementations can override for specific behavior
        return []
    }

    /// Remove notification requests by identifiers
    func removeRequests(withIdentifiers ids: [String]) async {
        // Default no-op implementation
        // Concrete implementations can override
    }

    /// Clean up all notifications for a dismissed occurrence
    func cleanupOccurrence(alarmId: UUID, occurrenceKey: String) async {
        // Default implementation calls cancelOccurrence
        await cancelOccurrence(alarmId: alarmId, occurrenceKey: occurrenceKey)
    }
}```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/AlarmAudioEngineError.swift

```swift
//
//  AlarmAudioEngineError.swift
//  alarmAppNew
//
//  Domain-level error protocol for alarm audio engine operations.
//  Keeps Infrastructure layer fully typed per CLAUDE.md §5.
//

import Foundation

/// Domain-level errors for alarm audio engine operations.
///
/// This enum provides a clean abstraction over AVFoundation and audio playback errors,
/// following the same pattern as AlarmSchedulingError and AlarmRunStoreError.
public enum AlarmAudioEngineError: Error, Equatable {
    case assetNotFound(soundName: String)
    case sessionActivationFailed
    case playbackFailed(reason: String)
    case invalidState(expected: String, actual: String)

    /// Human-readable description for logging and debugging
    public var description: String {
        switch self {
        case .assetNotFound(let soundName):
            return "Audio asset '\(soundName).caf' not found in bundle"
        case .sessionActivationFailed:
            return "Failed to activate AVAudioSession"
        case .playbackFailed(let reason):
            return "Audio playback failed: \(reason)"
        case .invalidState(let expected, let actual):
            return "Invalid audio engine state - expected: \(expected), actual: \(actual)"
        }
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/AlarmSoundEngine.swift

```swift
import AVFoundation
import Foundation
import UIKit

// MARK: - Protocol Definition

protocol AlarmAudioEngineProtocol {
    func schedulePrewarm(fireAt: Date, soundName: String) throws
    func promoteToRinging() throws
    func playForegroundAlarm(soundName: String) throws  // Renamed from playImmediate
    func scheduleWithLeadIn(fireAt: Date, soundId: String, leadInSeconds: Int) throws
    func stop()
    func setPolicyProvider(_ provider: @escaping () -> AudioPolicy)
    var currentState: AlarmSoundEngine.State { get }
    var isActivelyRinging: Bool { get }
}

// MARK: - State Machine Implementation

final class AlarmSoundEngine: AlarmAudioEngineProtocol {

    // MARK: - Dependencies
    private var reliabilityModeProvider: ReliabilityModeProvider?
    private var currentReliabilityMode: ReliabilityMode = .notificationsOnly
    private var policyProvider: (() -> AudioPolicy)?
    private var didActivateSession = false  // Track whether we activated AVAudioSession

    enum State: Equatable {
        case idle
        case prewarming
        case ringing

        var description: String {
            switch self {
            case .idle: return "idle"
            case .prewarming: return "prewarming"
            case .ringing: return "ringing"
            }
        }
    }
    static let shared = AlarmSoundEngine()

    // MARK: - State Machine
    private var _currentState: State = .idle
    private let stateQueue = DispatchQueue(label: "alarm-sound-engine-state", qos: .userInteractive)

    var currentState: State {
        return stateQueue.sync { _currentState }
    }

    var isActivelyRinging: Bool {
        return currentState == .ringing
    }

    // MARK: - Audio Players and Tasks
    private var mainPlayer: AVAudioPlayer?
    private var prewarmPlayer: AVAudioPlayer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Route Enforcement and Timing
    private var routeEnforcementTimer: DispatchSourceTimer?
    private var lastOverrideAttempt: Date?
    private var scheduledFireDate: Date?

    // MARK: - Notification Observers
    private var observers: [NSObjectProtocol] = []
    private var observersRegistered = false

    private init() {
        // NO AVAudioSession calls here - fully lazy activation
        setupNotificationObservers()
        setupAppLifecycleObserver()
    }

    // MARK: - Dependency Injection

    func setReliabilityModeProvider(_ provider: ReliabilityModeProvider) {
        self.reliabilityModeProvider = provider

        // Subscribe to mode changes and update cached value
        Task { @MainActor in
            self.currentReliabilityMode = provider.currentMode

            // Subscribe to future changes
            Task {
                for await mode in provider.modePublisher.values {
                    await MainActor.run {
                        self.currentReliabilityMode = mode
                        print("🔊 AlarmSoundEngine: Reliability mode changed to: \(mode.rawValue)")

                        // If switching to notifications only, stop any active audio
                        if mode == .notificationsOnly && self.currentState != .idle {
                            print("🔇 AlarmSoundEngine: IMMEDIATE STOP - mode switched to notifications only")
                            self.stop()
                        }
                    }
                }
            }
        }

        print("🔊 AlarmSoundEngine: ReliabilityModeProvider injected")
    }

    func setPolicyProvider(_ provider: @escaping () -> AudioPolicy) {
        self.policyProvider = provider
        print("🔊 AlarmSoundEngine: PolicyProvider injected")
    }

    deinit {
        removeNotificationObservers()
    }

    // MARK: - State Management

    private func setState(_ newState: State) {
        stateQueue.sync {
            let oldState = _currentState
            _currentState = newState
            print("🔊 AlarmSoundEngine: State transition: \(oldState.description) → \(newState.description)")
        }
    }

    private func guardState(_ expectedStates: State..., operation: String) -> Bool {
        let current = currentState
        let isValid = expectedStates.contains(current)
        if !isValid {
            print("🔊 AlarmSoundEngine: ⚠️ Ignoring \(operation) - invalid state \(current.description), expected: \(expectedStates.map(\.description).joined(separator: " or "))")
        }
        return isValid
    }

    // MARK: - Audio Session Management

    /// Prime the audio session for alarm playback with forced speaker routing
    @MainActor
    func activateSession(policy: AudioPolicy) throws {
        let session = AVAudioSession.sharedInstance()

        // Use .playback category (NOT .playAndRecord)
        // NOTE: Removed .duckOthers to prevent iOS from ducking notification sounds when backgrounded
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]

        try session.setCategory(.playback, options: options)

        // Force override any existing route preferences
        try session.overrideOutputAudioPort(.speaker)
        try session.setActive(true)
        didActivateSession = true  // Set flag after activation

        // Log current audio route for diagnostics
        let currentRoute = session.currentRoute
        let outputs = currentRoute.outputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
        print("🔊 AlarmSoundEngine: Audio session activated with .playback + .defaultToSpeaker")
        print("🔊 AlarmSoundEngine: Current audio route outputs: \(outputs)")
    }

    // MARK: - Protocol API Implementation

    /// Schedule prewarm to begin near fire time (controlled timing)
    func schedulePrewarm(fireAt: Date, soundName: String) throws {
        // CRITICAL: Early return if reliability mode is notifications only
        guard currentReliabilityMode == .notificationsPlusAudio else {
            print("🔇 AlarmSoundEngine: Skipping schedulePrewarm because reliabilityMode=notificationsOnly")
            return
        }

        guard guardState(.idle, operation: "schedulePrewarm") else { return }

        let delta = fireAt.timeIntervalSinceNow
        print("🔊 AlarmSoundEngine: Scheduling prewarm for \(fireAt) (delta: \(delta)s)")

        // Only prewarm for imminent alarms (≤60s)
        guard delta <= 60.0 && delta > 0 else {
            print("🔊 AlarmSoundEngine: Prewarm skipped - delta \(delta)s outside window (≤60s)")
            return
        }

        scheduledFireDate = fireAt
        setState(.prewarming)

        // Start background transition monitoring
        // TODO: Add app lifecycle integration

        print("🔊 AlarmSoundEngine: Prewarm scheduled successfully")
    }

    /// Promote existing prewarm to full ringing
    @MainActor
    func promoteToRinging() throws {
        // CRITICAL: Early return if reliability mode is notifications only
        guard currentReliabilityMode == .notificationsPlusAudio else {
            print("🔇 AlarmSoundEngine: Skipping promoteToRinging because reliabilityMode=notificationsOnly")
            return
        }

        guard guardState(.prewarming, operation: "promoteToRinging") else {
            // If not prewarming, fall back to foreground alarm
            if currentState == .idle {
                print("🔊 AlarmSoundEngine: No prewarm active, falling back to foreground alarm")
                try playForegroundAlarm(soundName: "ringtone1")
                return
            }
            return
        }

        print("🔊 AlarmSoundEngine: Promoting prewarm to ringing")
        let soundURL = try getBundledSoundURL("ringtone1")
        try handoffToMainAlarm(soundURL: soundURL, loops: -1, volume: 1.0)
        setState(.ringing)
    }

    /// Play alarm in foreground (foreground-only, policy-gated)
    /// MUST-FIX: Not async, use @MainActor for AVAudioSession calls
    @MainActor
    func playForegroundAlarm(soundName: String) throws {
        guard let policy = policyProvider?() else {
            print("🔊 AlarmSoundEngine: No policy configured - skipping playback")
            return
        }

        // Capability guard: only .foregroundAssist and .sleepMode can play AV audio
        guard policy.capability == .foregroundAssist || policy.capability == .sleepMode else {
            print("🔊 AlarmSoundEngine: Capability check failed - policy: \(policy.capability)")
            return
        }

        // Foreground guard: .foregroundAssist requires app to be active
        if policy.capability == .foregroundAssist {
            guard UIApplication.shared.applicationState == .active else {
                print("🔊 AlarmSoundEngine: Not in foreground, skipping AV playback (foregroundAssist)")
                return
            }
        }

        guard guardState(.idle, operation: "playForegroundAlarm") else { return }

        print("🔊 AlarmSoundEngine: Starting foreground alarm playback of \(soundName)")
        setState(.ringing)

        // Activate session and play immediately
        try activateSession(policy: policy)

        let soundURL = try getBundledSoundURL(soundName)
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.numberOfLoops = -1
        player.volume = 1.0
        player.prepareToPlay()

        guard player.play() else {
            setState(.idle)
            didActivateSession = false
            throw AlarmAudioEngineError.playbackFailed(reason: "Failed to start foreground alarm playback")
        }

        mainPlayer = player
        startRouteEnforcementWindow()
        print("🔊 AlarmSoundEngine: ✅ Foreground alarm playback started")
    }

    /// Start sleep mode audio in background (if capability allows)
    @MainActor
    func startSleepAudioIfEnabled(soundName: String) throws {
        guard let policy = policyProvider?() else {
            print("🔊 AlarmSoundEngine: No policy configured - skipping sleep audio")
            return
        }

        // Capability guard: only .sleepMode can play in background
        guard policy.capability == .sleepMode else {
            print("🔊 AlarmSoundEngine: Sleep audio requires .sleepMode capability")
            return
        }

        guard guardState(.idle, operation: "startSleepAudioIfEnabled") else { return }

        print("🔊 AlarmSoundEngine: Starting sleep mode audio in background")
        setState(.ringing)

        // Activate session and play
        try activateSession(policy: policy)

        let soundURL = try getBundledSoundURL(soundName)
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.numberOfLoops = -1
        player.volume = 1.0
        player.prepareToPlay()

        guard player.play() else {
            setState(.idle)
            didActivateSession = false
            throw AlarmAudioEngineError.playbackFailed(reason: "Failed to start sleep mode audio")
        }

        mainPlayer = player
        startRouteEnforcementWindow()
        print("🔊 AlarmSoundEngine: ✅ Sleep mode audio started in background")
    }

    /// Schedule audio with lead-in time (audio enhancement for primary notifications)
    @MainActor
    func scheduleWithLeadIn(fireAt: Date, soundId: String, leadInSeconds: Int) throws {
        // CRITICAL: Early return if reliability mode is notifications only
        guard currentReliabilityMode == .notificationsPlusAudio else {
            print("🔇 AlarmSoundEngine: Skipping scheduleWithLeadIn because reliabilityMode=notificationsOnly")
            return
        }

        guard guardState(.idle, operation: "scheduleWithLeadIn") else { return }

        let delta = fireAt.timeIntervalSinceNow
        print("🔊 AlarmSoundEngine: Scheduling audio with lead-in for \(fireAt) (delta: \(delta)s, leadIn: \(leadInSeconds)s)")

        // Validate lead-in timing
        guard delta > Double(leadInSeconds) else {
            print("🔊 AlarmSoundEngine: ⚠️ Lead-in (\(leadInSeconds)s) exceeds delta (\(delta)s) - using foreground playback")
            try playForegroundAlarm(soundName: soundId)
            return
        }

        scheduledFireDate = fireAt
        setState(.prewarming)

        // Calculate audio start time (fireAt - leadInSeconds)
        let audioStartDelay = delta - Double(leadInSeconds)

        print("🔊 AlarmSoundEngine: Audio will start in \(audioStartDelay)s (lead-in: \(leadInSeconds)s before alarm)")

        // Schedule audio start
        DispatchQueue.main.asyncAfter(deadline: .now() + audioStartDelay) { [weak self] in
            guard let self = self, self.currentState == .prewarming else { return }
            guard let policy = self.policyProvider?() else {
                print("🔊 AlarmSoundEngine: No policy configured - aborting lead-in")
                self.setState(.idle)
                return
            }

            Task { @MainActor in
                do {
                    // Activate session and start ringing
                    try self.activateSession(policy: policy)

                    let soundURL = try self.getBundledSoundURL(soundId)
                    let player = try AVAudioPlayer(contentsOf: soundURL)
                    player.numberOfLoops = -1
                    player.volume = 1.0
                    player.prepareToPlay()

                    guard player.play() else {
                        print("🔊 AlarmSoundEngine: ❌ Failed to start lead-in playback")
                        self.setState(.idle)
                        self.didActivateSession = false
                        return
                    }

                    self.mainPlayer = player
                    self.setState(.ringing)
                    self.startRouteEnforcementWindow()

                    print("🔊 AlarmSoundEngine: ✅ Lead-in audio started at T-\(leadInSeconds)s")
                } catch {
                    print("🔊 AlarmSoundEngine: ❌ Lead-in activation failed: \(error)")
                    self.setState(.idle)
                }
            }
        }

        print("🔊 AlarmSoundEngine: Lead-in scheduled successfully")
    }

    private func getBundledSoundURL(_ soundName: String) throws -> URL {
        if let url = Bundle.main.url(forResource: soundName, withExtension: "caf") {
            return url
        }
        // Fallback to ringtone1
        guard let fallbackURL = Bundle.main.url(forResource: "ringtone1", withExtension: "caf") else {
            throw AlarmAudioEngineError.assetNotFound(soundName: "\(soundName) (fallback also missing)")
        }
        print("🔊 AlarmSoundEngine: Using fallback ringtone1.caf for \(soundName)")
        return fallbackURL
    }

    /// DEPRECATED: Legacy schedule method - replaced by protocol API
    @MainActor
    private func schedule(soundURL: URL, fireAt date: Date, loops: Int = -1, volume: Float = 1.0) throws {
        // Stop any existing audio first
        stop()

        let delta = date.timeIntervalSinceNow
        self.scheduledFireDate = date

        // PRE-ACTIVATION STRATEGY: For imminent alarms (≤60s), pre-activate session while foregrounded
        if delta <= 60.0 && delta > 5.0 {
            // Imminent alarm - start pre-activation with compliant prewarm
            print("🔊 AlarmSoundEngine: Imminent alarm detected (delta: \(delta)s) - starting pre-activation")
            try startPreActivation(mainSoundURL: soundURL, fireAt: date, loops: loops, volume: volume)
        } else if delta <= 5.0 {
            // Very short delay - activate session immediately
            guard let policy = policyProvider?() else {
                print("🔊 AlarmSoundEngine: No policy configured - aborting immediate schedule")
                return
            }
            Task { @MainActor in
                try self.activateSession(policy: policy)
                try self.schedulePlayerImmediate(soundURL: soundURL, fireAt: date, loops: loops, volume: volume, delta: delta)
            }
        } else {
            // Longer delay - use traditional deferred activation (may fail in background)
            print("🔊 AlarmSoundEngine: Long delay (delta: \(delta)s) - using deferred activation")
            try schedulePlayerDeferred(soundURL: soundURL, fireAt: date, loops: loops, volume: volume)
        }

        // State managed by new protocol API
        print("🔊 AlarmSoundEngine: Scheduled audio at \(date) (delta: \(delta)s, loops: \(loops))")
    }

    /// Schedule player immediately (for short delays ≤5s)
    private func schedulePlayerImmediate(soundURL: URL, fireAt date: Date, loops: Int, volume: Float, delta: TimeInterval) throws {
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.numberOfLoops = loops
        player.volume = volume
        player.prepareToPlay()

        let startAt = player.deviceCurrentTime + max(0.5, delta)

        guard player.play(atTime: startAt) else {
            throw AlarmAudioEngineError.playbackFailed(reason: "AVAudioPlayer failed to schedule play(atTime:)")
        }

        self.mainPlayer = player

        // Start route enforcement window to fight Apple Watch hijacking
        startRouteEnforcementWindow()
    }

    /// Schedule player with deferred activation (for longer delays >5s)
    private func schedulePlayerDeferred(soundURL: URL, fireAt date: Date, loops: Int, volume: Float) throws {
        // Calculate when to activate session (1 second before fire time)
        let activationTime = date.addingTimeInterval(-1.0)
        let activationDelay = max(0.1, activationTime.timeIntervalSinceNow)

        // Schedule session activation and playback
        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay) { [weak self] in
            guard let self = self, self.currentState != .idle else { return }
            guard let policy = self.policyProvider?() else {
                print("🔊 AlarmSoundEngine: No policy configured - aborting deferred activation")
                return
            }

            Task { @MainActor in
                do {
                    // PREWARM: Activate session at T-1s for optimal speaker seizure timing
                    try self.activateSession(policy: policy)

                    let player = try AVAudioPlayer(contentsOf: soundURL)
                    player.numberOfLoops = loops
                    player.volume = volume
                    player.prepareToPlay()

                    // Play immediately since we're now at T-1s
                    let remainingDelay = max(0.1, date.timeIntervalSinceNow)
                    let startAt = player.deviceCurrentTime + remainingDelay

                    guard player.play(atTime: startAt) else {
                        print("🔊 AlarmSoundEngine: ❌ Deferred play(atTime:) failed")
                        self.didActivateSession = false
                        return
                    }

                    self.mainPlayer = player

                    // Start route enforcement window to fight Apple Watch hijacking
                    self.startRouteEnforcementWindow()

                    print("🔊 AlarmSoundEngine: ✅ Deferred activation successful at T-\(remainingDelay)s")
                } catch {
                    print("🔊 AlarmSoundEngine: ❌ Deferred activation failed: \(error)")
                }
            }
        }
    }

    /// Stop alarm audio and deactivate session
    @MainActor
    func stop() {
        let previousState = currentState

        // Stop all audio players
        mainPlayer?.stop()
        mainPlayer = nil
        stopPrewarm()

        // Stop route enforcement
        stopRouteEnforcementWindow()

        // End background task
        endBackgroundTask()

        // Reset state
        setState(.idle)
        scheduledFireDate = nil

        // Only deactivate if we activated it
        if didActivateSession {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                didActivateSession = false
                print("🔊 AlarmSoundEngine: Stopped audio and deactivated session (was: \(previousState.description))")
            } catch {
                print("🔊 AlarmSoundEngine: Error deactivating session: \(error)")
            }
        } else {
            print("🔊 AlarmSoundEngine: Stopped audio without deactivating session (never activated, was: \(previousState.description))")
        }
    }

    // MARK: - Interruption Recovery

    private func setupNotificationObservers() {
        // Observer de-dup: register only once
        guard !observersRegistered else {
            print("🔊 AlarmSoundEngine: Observers already registered - skipping duplicate registration")
            return
        }

        // Handle audio interruptions (phone calls, etc.)
        let interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        // Handle route changes (Bluetooth connect/disconnect, etc.)
        let routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }

        // CRITICAL: Store observer tokens to prevent deallocation
        observers = [interruptionObserver, routeChangeObserver]
        observersRegistered = true

        print("🔊 AlarmSoundEngine: Notification observers registered")
    }

    private func removeNotificationObservers() {
        guard observersRegistered else { return }

        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        observersRegistered = false

        print("🔊 AlarmSoundEngine: Notification observers removed")
    }

    // MARK: - App Lifecycle Observer

    private func setupAppLifecycleObserver() {
        // Observe app moving to background
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }

        // Observe app returning to foreground
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }

        observers.append(contentsOf: [backgroundObserver, foregroundObserver])
        print("🔊 AlarmSoundEngine: App lifecycle observers registered")
    }

    @MainActor
    private func handleAppDidEnterBackground() {
        guard let policy = policyProvider?() else { return }

        // Only .foregroundAssist needs special handling on backgrounding
        if policy.capability == .foregroundAssist && currentState == .ringing {
            print("🔊 AlarmSoundEngine: App backgrounded with foregroundAssist - stopping audio")
            stop()
        }
    }

    @MainActor
    private func handleAppWillEnterForeground() {
        // Currently no special handling needed on foreground
        // Audio will be restarted by dismissal flow if alarm is still active
        print("🔊 AlarmSoundEngine: App foregrounded")
    }

    @MainActor
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("🔊 AlarmSoundEngine: Audio interrupted")

        case .ended:
            // Attempt to resume if we're within the alarm window
            guard currentState != .idle else { return }
            guard let policy = policyProvider?() else { return }

            do {
                try activateSession(policy: policy)
                mainPlayer?.play()
                print("🔊 AlarmSoundEngine: Resumed after interruption")
            } catch {
                print("🔊 AlarmSoundEngine: Failed to resume after interruption: \(error)")
            }

        @unknown default:
            break
        }
    }

    @MainActor
    private func handleRouteChange(_ notification: Notification) {
        guard currentState != .idle else { return }

        // Check if we should skip this override attempt (debounce logic)
        if shouldSkipRouteOverride() {
            print("🔊 AlarmSoundEngine: Skipping route override (debounce active)")
            return
        }

        // Re-assert speaker routing after route changes
        performRouteOverride(context: "route change")
    }

    // MARK: - Pre-Activation and Background Task Management

    /// Start pre-activation with compliant prewarm for imminent alarms
    @MainActor
    private func startPreActivation(mainSoundURL: URL, fireAt date: Date, loops: Int, volume: Float) throws {
        guard let policy = policyProvider?() else {
            print("🔊 AlarmSoundEngine: No policy configured - aborting pre-activation")
            return
        }

        // Begin background task to maintain capability across foreground→background transition
        startBackgroundTask()

        // Activate session while foregrounded
        try activateSession(policy: policy)

        // Start compliant prewarm audio loop
        try startCompliantPrewarm()

        // Schedule the handoff to main alarm audio
        let fireDelay = date.timeIntervalSinceNow
        DispatchQueue.main.asyncAfter(deadline: .now() + fireDelay) { [weak self] in
            self?.handoffToMainAlarm(soundURL: mainSoundURL, loops: loops, volume: volume)
        }

        print("🔊 AlarmSoundEngine: Pre-activation started with compliant prewarm")
    }

    /// Start compliant prewarm audio with real samples at low volume
    private func startCompliantPrewarm() throws {
        // CRITICAL: Bundle asset validation - hard error if missing
        guard let prewarmURL = Bundle.main.url(forResource: "prewarm", withExtension: "caf") else {
            let error = AlarmAudioEngineError.assetNotFound(soundName: "prewarm")
            print("🔊 AlarmSoundEngine: ❌ Bundle assert failed: \(error.description)")
            print("🔊 AlarmSoundEngine: ❌ Verify prewarm.caf is in Copy Bundle Resources with correct Target Membership")
            throw error
        }

        let prewarmPlayer = try AVAudioPlayer(contentsOf: prewarmURL)
        prewarmPlayer.numberOfLoops = -1  // Infinite loop
        prewarmPlayer.volume = 0.01       // Imperceptible but real audio (~5s sample)
        prewarmPlayer.prepareToPlay()

        guard prewarmPlayer.play() else {
            throw AlarmAudioEngineError.playbackFailed(reason: "Failed to start prewarm audio")
        }

        self.prewarmPlayer = prewarmPlayer
        print("🔊 AlarmSoundEngine: ✅ Silent prewarm started with prewarm.caf at volume \(prewarmPlayer.volume)")
    }

    /// Stop prewarm audio
    private func stopPrewarm() {
        prewarmPlayer?.stop()
        prewarmPlayer = nil
        print("🔊 AlarmSoundEngine: Prewarm stopped")
    }

    /// Handoff from prewarm to main alarm audio
    private func handoffToMainAlarm(soundURL: URL, loops: Int, volume: Float) {
        guard currentState != .idle else { return }

        do {
            // Stop prewarm
            stopPrewarm()

            // Start main alarm audio
            let mainPlayer = try AVAudioPlayer(contentsOf: soundURL)
            mainPlayer.numberOfLoops = loops
            mainPlayer.volume = volume
            mainPlayer.prepareToPlay()

            guard mainPlayer.play() else {
                print("🔊 AlarmSoundEngine: ❌ Failed to start main alarm audio")
                return
            }

            self.mainPlayer = mainPlayer

            // Start route enforcement to fight Apple Watch hijacking
            startRouteEnforcementWindow()

            print("🔊 AlarmSoundEngine: ✅ Handoff to main alarm audio successful")
        } catch {
            print("🔊 AlarmSoundEngine: ❌ Handoff to main alarm failed: \(error)")
        }
    }

    /// Start background task to maintain audio capability
    private func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AlarmAudio") { [weak self] in
            // Background task is about to expire - clean up safely
            guard let self = self else { return }

            print("🔊 AlarmSoundEngine: ⚠️ Background task expiring - performing safety cleanup")

            // Stop prewarm audio
            self.stopPrewarm()

            // Stop main player if not ringing yet
            if self.currentState == .prewarming {
                self.mainPlayer?.stop()
                self.mainPlayer = nil
                print("🔊 AlarmSoundEngine: Stopped main player during expiration (was prewarming)")
            }

            // CRITICAL: Main-thread boundary for AVAudioSession calls
            Task { @MainActor in
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                    print("🔊 AlarmSoundEngine: Deactivated session on expiration")
                } catch {
                    print("🔊 AlarmSoundEngine: Failed to deactivate session on expiration: \(error)")
                }
            }

            // Reset state
            self.setState(.idle)

            // End the background task
            self.endBackgroundTask()
        }

        print("🔊 AlarmSoundEngine: Background task started: \(backgroundTask.rawValue)")
    }

    /// End background task
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        // CRITICAL: Main-thread boundary for UIApplication calls
        Task { @MainActor in
            UIApplication.shared.endBackgroundTask(backgroundTask)
            print("🔊 AlarmSoundEngine: Background task ended: \(backgroundTask.rawValue)")
        }
        backgroundTask = .invalid
    }

    // MARK: - Route Enforcement Window

    /// Start periodic route enforcement to fight Apple Watch hijacking
    private func startRouteEnforcementWindow() {
        // Stop any existing timer first
        stopRouteEnforcementWindow()

        // CRITICAL: Use DispatchSourceTimer (not Timer) for reliable background operation
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + 0.7, repeating: 0.7)

        timer.setEventHandler { [weak self] in
            guard let self = self, self.currentState != .idle else {
                self?.stopRouteEnforcementWindow()
                return
            }
            Task { @MainActor in
                self.enforcePhoneSpeakerRoute()
            }
        }

        // Store strong reference to prevent deallocation
        routeEnforcementTimer = timer
        timer.resume()

        // Stop enforcement after 15 seconds automatically
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            self?.stopRouteEnforcementWindow()
        }

        print("🔊 AlarmSoundEngine: Started route enforcement window (15s) with DispatchSourceTimer")
    }

    /// Stop route enforcement timer (DispatchSourceTimer)
    private func stopRouteEnforcementWindow() {
        routeEnforcementTimer?.cancel()
        routeEnforcementTimer = nil
        print("🔊 AlarmSoundEngine: Route enforcement timer cancelled")
    }

    /// Enforce phone speaker route - called periodically during alarm
    @MainActor
    private func enforcePhoneSpeakerRoute() {
        guard currentState != .idle else { return }

        // Policy guard: only override if policy allows
        guard let policy = policyProvider?(), policy.allowRouteOverrideAtAlarm else {
            print("🔊 AlarmSoundEngine: Route override not allowed by policy - skipping enforcement")
            return
        }

        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        // Check current output route
        let outputs = currentRoute.outputs
        let isOnPhoneSpeaker = outputs.contains { output in
            output.portType == .builtInSpeaker || output.portName.contains("Speaker")
        }

        if isOnPhoneSpeaker {
            // Already on phone speaker - log success and STOP enforcement timer
            let outputNames = outputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
            print("🔊 AlarmSoundEngine: ✅ Route enforcement success: \(outputNames) - stopping timer")
            stopRouteEnforcementWindow()
            return
        }

        // Check if we should skip this override attempt (debounce logic)
        if shouldSkipRouteOverride() {
            let outputNames = outputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
            print("🔊 AlarmSoundEngine: ⚠️ Route hijacked by: \(outputNames) - skipping override (debounce active)")
            return
        }

        // Not on phone speaker - re-assert routing
        let outputNames = outputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
        print("🔊 AlarmSoundEngine: ⚠️ Route hijacked by: \(outputNames) - re-asserting speaker")

        performRouteOverride(context: "enforcement timer")
    }

    // MARK: - Debounce Logic

    /// Check if we should skip route override (debounce logic)
    private func shouldSkipRouteOverride() -> Bool {
        let session = AVAudioSession.sharedInstance()
        let now = Date()

        // Check if current route is already Built-In Speaker
        let currentRoute = session.currentRoute
        let isOnPhoneSpeaker = currentRoute.outputs.contains { output in
            output.portType == .builtInSpeaker || output.portName.contains("Speaker")
        }

        // Check if last override attempt was within debounce window (~700ms)
        let isWithinDebounceWindow: Bool
        if let lastAttempt = lastOverrideAttempt {
            isWithinDebounceWindow = now.timeIntervalSince(lastAttempt) < 0.7
        } else {
            isWithinDebounceWindow = false
        }

        // Skip if already on speaker AND within debounce window
        let shouldSkip = isOnPhoneSpeaker && isWithinDebounceWindow

        if shouldSkip {
            print("🔊 AlarmSoundEngine: Debounce conditions met - onSpeaker: \(isOnPhoneSpeaker), withinWindow: \(isWithinDebounceWindow)")
        }

        return shouldSkip
    }

    /// Perform route override with session checks
    @MainActor
    private func performRouteOverride(context: String) {
        // Policy guard: only override if policy allows
        guard let policy = policyProvider?(), policy.allowRouteOverrideAtAlarm else {
            print("🔊 AlarmSoundEngine: Route override not allowed by policy (\(context))")
            return
        }

        let session = AVAudioSession.sharedInstance()

        do {
            // Re-apply aggressive speaker routing
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true, options: [])
            didActivateSession = true  // Update flag after activation

            // Update debounce timestamp
            lastOverrideAttempt = Date()

            print("🔊 AlarmSoundEngine: 🔄 Route override successful (\(context))")
        } catch {
            print("🔊 AlarmSoundEngine: ❌ Route override failed (\(context)): \(error)")
        }
    }
}

// MARK: - Convenience Methods

extension AlarmSoundEngine {
    /// Schedule alarm with bundled sound file
    @MainActor
    func scheduleAlarm(soundName: String = "ringtone1", extension: String = "caf", fireAt date: Date) throws {
        // CRITICAL: Hard existence check - refuse to pretend success if file missing
        guard let url = Bundle.main.url(forResource: soundName, withExtension: `extension`) else {
            // Try ultimate fallback to ringtone1 if not already trying it
            if soundName != "ringtone1" {
                print("🔊 AlarmSoundEngine: '\(soundName).\(`extension`)' not found, trying ultimate fallback 'ringtone1.caf'")
                guard let fallbackURL = Bundle.main.url(forResource: "ringtone1", withExtension: "caf") else {
                    throw AlarmAudioEngineError.assetNotFound(soundName: "\(soundName) (fallback also missing)")
                }
                try schedule(soundURL: fallbackURL, fireAt: date)
                print("🔊 AlarmSoundEngine: ✅ Using fallback 'ringtone1.caf' successfully")
                return
            }

            // Even ringtone1 not found - hard failure
            throw AlarmAudioEngineError.assetNotFound(soundName: soundName)
        }

        try schedule(soundURL: url, fireAt: date)
        print("🔊 AlarmSoundEngine: ✅ Scheduled with '\(soundName).\(`extension`)' successfully")
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/IdleTimerControlling.swift

```swift
//
//  IdleTimerControlling.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/10/25.
//  Protocol for controlling screen idle timer state
//

import Foundation

/// Protocol for controlling the device screen idle timer.
/// This abstraction allows ViewModels to keep the screen awake without directly depending on UIKit.
public protocol IdleTimerControlling {
    /// Sets whether the idle timer should be disabled.
    /// - Parameter disabled: If true, prevents the screen from sleeping; if false, allows normal sleep behavior
    func setIdleTimer(disabled: Bool)
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Infrastructure/UIApplicationIdleTimerController.swift

```swift
//
//  UIApplicationIdleTimerController.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/10/25.
//  Concrete implementation of IdleTimerControlling using UIApplication
//

import UIKit

/// Concrete implementation that controls the screen idle timer via UIApplication.
/// This isolates UIKit dependencies to the Infrastructure layer.
@MainActor
final class UIApplicationIdleTimerController: IdleTimerControlling {
    func setIdleTimer(disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Coordinators/AppRouter.swift

```swift
//
//  AppRouter.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/20/25.
//

// alarmAppNew/…/AppRouter.swift
import SwiftUI

protocol AppRouting {
    func showRinging(for id: UUID, intentAlarmID: UUID?)
    func backToList()
}

@MainActor
final class AppRouter: ObservableObject, AppRouting {
    enum Route: Equatable {
        case alarmList
        case ringing(alarmID: UUID, intentAlarmID: UUID? = nil)   // Enforced ringing route for MVP1
    }

    @Published var route: Route = .alarmList

    // Single-instance guard: track if dismissal flow is active
    private var activeDismissalAlarmId: UUID?

    // Store the intent alarm ID separately (could be pre-migration ID)
    private var currentIntentAlarmId: UUID?

    func showRinging(for id: UUID, intentAlarmID: UUID? = nil) {
        // Strengthen double-route guard
        if activeDismissalAlarmId == id, case .ringing(let current, _) = route, current == id {
            return // already showing this alarm
        }

        print("AppRouter: Showing ringing for alarm: \(id), intentAlarmID: \(intentAlarmID?.uuidString.prefix(8) ?? "nil")")
        activeDismissalAlarmId = id
        currentIntentAlarmId = intentAlarmID
        route = .ringing(alarmID: id, intentAlarmID: intentAlarmID)
        print("AppRouter: Route set to ringing, activeDismissalAlarmId: \(activeDismissalAlarmId?.uuidString.prefix(8) ?? "nil")")
    }

    func backToList() {
        // Clear active dismissal state when returning to list
        activeDismissalAlarmId = nil
        currentIntentAlarmId = nil
        route = .alarmList
    }
    
    // Getter for testing and debugging
    var isInDismissalFlow: Bool {
        return activeDismissalAlarmId != nil
    }

    var currentDismissalAlarmId: UUID? {
        return activeDismissalAlarmId
    }

    var currentIntentAlarmIdValue: UUID? {
        return currentIntentAlarmId
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/ContentView.swift

```swift
// alarmAppNew/…/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        // Unwrap container - should always be present from app root
        guard let container = container else {
            return AnyView(Text("Configuration error: Container not injected")
                .foregroundColor(.red))
        }

        return AnyView(
            Group {
                switch router.route {
                case .alarmList:
                    AlarmsListView(container: container)
                case .ringing(let id, let intentAlarmID):
                    RingingView(alarmID: id, intentAlarmID: intentAlarmID, container: container)
                        .environmentObject(container)  // Inject for child views (ScanningContent, FailedContent)
                        .interactiveDismissDisabled(true)
                }
            }
        )
    }
}

#Preview {
    let container = DependencyContainer()
    return ContentView()
        .environmentObject(AppRouter())
        .environment(\.container, container)
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/AlarmFormView.swift

```swift
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
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/AlarmsListView.swift

```swift
//
//  AlarmsListView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI
import UserNotifications

struct AlarmsListView: View {

  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var router: AppRouter
  @StateObject private var vm: AlarmListViewModel
  @State private var detailVM: AlarmDetailViewModel?
  @State private var showSettings = false

  // Store container for child views
  private let container: DependencyContainer

  // Primary initializer - accepts injected container
  init(container: DependencyContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: container.makeAlarmListViewModel())
    }

    // For testing/preview purposes with a pre-configured view model
    init(preConfiguredVM: AlarmListViewModel, container: DependencyContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: preConfiguredVM)
    }

  var body: some View {
    NavigationStack {
      ZStack {
        // Empty state
        if vm.alarms.isEmpty {
          ContentUnavailableView(
            "No Alarms",
            systemImage: "alarm",
            description: Text("Tap + to create your first alarm")
          )
        }

        // Alarm list
        List {
          // Permission warning section
          if let permissionDetails = vm.notificationPermissionDetails {
            Section {
              NotificationPermissionInlineWarning(
                permissionDetails: permissionDetails,
                permissionService: container.permissionService
              )
            }
          }

          // Media volume warning banner
          if vm.showMediaVolumeWarning {
            Section {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Image(systemName: "speaker.wave.1")
                    .foregroundColor(.orange)
                  Text("Low Media Volume Detected")
                    .font(.headline)
                    .foregroundColor(.orange)
                }

                Text("Your media volume is low. This won't affect lock-screen alarms (they use ringer volume), but in-app sounds may be quiet.")
                  .font(.caption)
                  .foregroundColor(.secondary)

                Button("Dismiss") {
                  vm.showMediaVolumeWarning = false
                }
                .font(.caption)
                .foregroundColor(.accentColor)
              }
              .padding(.vertical, 4)
            }
          }

          ForEach(vm.alarms) { alarm in
            AlarmRowView(
              alarm: alarm,
              onToggle: { vm.toggle(alarm) },
              onTap: { detailVM = AlarmDetailViewModel(alarm: alarm, isNew: false) }
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) {
                vm.delete(alarm)
              } label: {
                Label("Delete", systemImage: "trash")
              }

              Button {
                detailVM = AlarmDetailViewModel(alarm: alarm, isNew: false)
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .tint(.blue)
            }
          }
        }
        .listStyle(.insetGrouped)

        // Floating Action Button
        VStack {
          Spacer()
          HStack {
            Spacer()
            Button {
              detailVM = container.makeAlarmDetailViewModel()
            } label: {
              Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
          }
        }
      }
      .navigationTitle("Alarms")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button("Request Notification Permission", systemImage: "bell.badge") {
              Task {
                let center = UNUserNotificationCenter.current()
                do {
                  let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                  print("🔔 requestAuthorization returned: \(granted)")
                  let settings = await center.notificationSettings()
                  print("🔧 auth=\(settings.authorizationStatus.rawValue) alert=\(settings.alertSetting.rawValue) sound=\(settings.soundSetting.rawValue)")
                } catch {
                  print("❌ requestAuthorization error: \(error)")
                }
              }
            }

            Button("Test Lock Screen Notification", systemImage: "lock.circle") {
              Task {
                try? await container.notificationService.scheduleTestSystemDefault()
              }
            }

            Button("Test Lock-Screen Alarm (8s)", systemImage: "bell.badge.fill") {
              vm.testLockScreen()
            }

            Button("Run Sound Triage", systemImage: "stethoscope") {
              Task {
                try? await container.notificationService.runCompleteSoundTriage()
              }
            }

            Button("Bare Default Test", systemImage: "exclamationmark.triangle") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTest()
              }
            }

            Button("Bare Test (No Interruption)", systemImage: "bell.slash") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTestNoInterruption()
              }
            }

            Button("Bare Test (No Category)", systemImage: "bell.badge") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTestNoCategory()
              }
            }

            Divider()

            Button("Settings", systemImage: "gear") {
              showSettings = true
            }
          } label: {
            Image(systemName: "wrench.and.screwdriver")
          }
        }
      }
      .task {
          vm.refreshPermission()
        vm.ensureNotificationPermissionIfNeeded()
      // initial fetch when the screen appears
      }
      .onChange(of: scenePhase) { phase in
          if phase == .active {               // returning from Settings or prompt
              vm.refreshPermission()

              // Check for active alarms and route to ringing if needed
              Task {
                  if let (alarm, _) = await container.activeAlarmDetector.checkForActiveAlarm() {
                      print("📱 AlarmsListView: Auto-routing to ringing for alarm \(alarm.id.uuidString.prefix(8))")
                      router.showRinging(for: alarm.id, intentAlarmID: nil)
                  }
              }
          }
      }

    }
    .sheet(item: $detailVM) { formVM in
      AlarmFormView(detailVM: formVM, container: container) {
        if formVM.isNewAlarm {
          let newAlarm = formVM.commitChanges()
          vm.add(newAlarm)
        } else {
          vm.update(formVM.commitChanges())
        }
        detailVM = nil
      }
    }
    .sheet(isPresented: $vm.showPermissionBlocking) {
      NotificationPermissionBlockingView(
        permissionService: container.permissionService,
        onPermissionGranted: {
          vm.handlePermissionGranted()
        }
      )
    }
    // Note: .alarmDidFire notification removed with NotificationService migration to AlarmKit
    // AlarmKit handles alarm firing via intents and the activeAlarmDetector checks on app foreground
    .sheet(isPresented: $showSettings) {
      SettingsView(container: container)
    }
  }
}

// Separate row view for better organization
struct AlarmRowView: View {
  let alarm: Alarm
  let onToggle: () -> Void
  let onTap: () -> Void

  var body: some View {
    Button {
      onTap()
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(alarm.time, style: .time)
            .font(.largeTitle)
            .fontWeight(.light)

          HStack {
            Text(alarm.label)
              .font(.subheadline)
              .foregroundColor(.secondary)

            if !alarm.repeatDays.isEmpty {
              Text("•")
                .foregroundColor(.secondary)
              Text(alarm.repeatDaysText)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }

        Spacer()

        Toggle("", isOn: Binding(
          get: { alarm.isEnabled },
          set: { _ in onToggle() }
        ))
        .labelsHidden()
      }
      .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
    let container = DependencyContainer()
    let vm = container.makeAlarmListViewModel()

    vm.alarms = [
        Alarm(id: UUID(), time: Date(), label: "Morning", repeatDays: [.monday], challengeKind: [], isEnabled: true, soundId: "chimes01", volume: 0.5),
        Alarm(id: UUID(), time: Date(), label: "Work", repeatDays: [], challengeKind: [.math], isEnabled: true, soundId: "bells01", volume: 0.7),
        Alarm(id: UUID(), time: Date(), label: "Weekend", repeatDays: [.saturday, .sunday], challengeKind: [], isEnabled: false, soundId: "tone01", volume: 0.8)
    ]

    return AlarmsListView(preConfiguredVM: vm, container: container)
        .environmentObject(AppRouter())
        .environment(\.container, container)
}

```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/PersistenceService.swift

```swift
//
//  PersistenceService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/10/25.
//  Converted to actor for thread-safe persistence per CLAUDE.md §3
//

import Foundation


actor PersistenceService: PersistenceStore {
  private let userDefaultsKey = "savedAlarms"
  private let defaults: UserDefaults
  private let soundCatalog: SoundCatalogProviding
  private var hasPerformedRepair = false
  private var isRepairing = false

  init(defaults: UserDefaults = .standard, soundCatalog: SoundCatalogProviding? = nil) {
    self.defaults = defaults
    self.soundCatalog = soundCatalog ?? SoundCatalog(validateFiles: false)
  }

  func loadAlarms() throws -> [Alarm] {
    print("📂 PersistenceService.loadAlarms: Loading alarms from UserDefaults")
    guard let data = defaults.data(forKey: userDefaultsKey) else {
      print("📂 PersistenceService.loadAlarms: No data found, returning empty array")
      return []
    }

    print("📂 PersistenceService.loadAlarms: Found \(data.count) bytes")
    var alarms = try JSONDecoder().decode([Alarm].self, from: data)
    print("📂 PersistenceService.loadAlarms: Decoded \(alarms.count) alarms")

    // Perform one-time repair for invalid soundIds
    if !hasPerformedRepair {
      var needsRepair = false

      for i in alarms.indices {
        if soundCatalog.info(for: alarms[i].soundId) == nil {
          // Log the validation fix
          print("🔧 PersistenceService: Resetting invalid soundId '\(alarms[i].soundId)' to default '\(soundCatalog.defaultSoundId)' for alarm \(alarms[i].id)")

          // Direct soundId mutation approach
          alarms[i] = Alarm(
            id: alarms[i].id,
            time: alarms[i].time,
            label: alarms[i].label,
            repeatDays: alarms[i].repeatDays,
            challengeKind: alarms[i].challengeKind,
            expectedQR: alarms[i].expectedQR,
            stepThreshold: alarms[i].stepThreshold,
            mathChallenge: alarms[i].mathChallenge,
            isEnabled: alarms[i].isEnabled,
            soundId: soundCatalog.defaultSoundId,
            soundName: alarms[i].soundName,
            volume: alarms[i].volume,
            externalAlarmId: alarms[i].externalAlarmId
          )
          needsRepair = true
        }
      }

      if needsRepair && !isRepairing {
        isRepairing = true
        defer { isRepairing = false }
        try saveAlarms(alarms)
      }

      hasPerformedRepair = true
    }

    return alarms
  }
  
  func saveAlarms(_ alarms: [Alarm]) throws {
    print("💾 PersistenceService.saveAlarms: Saving \(alarms.count) alarms")
    let data = try JSONEncoder().encode(alarms)
    defaults.set(data, forKey: userDefaultsKey)
    defaults.synchronize() // Force immediate write
    print("💾 PersistenceService.saveAlarms: Successfully saved \(alarms.count) alarms (\(data.count) bytes)")
  }


}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Services/ServiceProtocolExtensions.swift

```swift
//
//  ServiceProtocolExtensions.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  Extensions to existing protocols for MVP1 dismissal flow
//

import Foundation
import SwiftUI

// MARK: - AlarmScheduling Extensions

extension AlarmScheduling {
    // Cancel notifications for a specific alarm ID
    func cancel(alarmId: UUID) async {
        // Implementation delegates to existing infrastructure
        // This creates the per-day IDs used by the current scheduling system
        let baseID = alarmId.uuidString
        
        // For repeat alarms, we need to cancel all weekday variations
        // The current system uses: "alarmId-weekday-X" format
        var idsToCancel = [baseID]
        
        // Add weekday variations (1-7 for Sunday-Saturday)
        for weekday in 1...7 {
            idsToCancel.append("\(baseID)-weekday-\(weekday)")
        }
        
        // Use the underlying notification center to cancel
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToCancel)
    }
}

// MARK: - Error Types

struct AlarmNotFoundError: Error {}

// MARK: - PersistenceStore Extensions

extension PersistenceStore {
    // Convenience method to find alarm by ID
    func alarm(with id: UUID) throws -> Alarm {
        let alarms = try loadAlarms()
        guard let alarm = alarms.first(where: { $0.id == id }) else {
            throw AlarmNotFoundError()
        }
        return alarm
    }
}

// MARK: - Test Clock

struct TestClock: Clock {
    private var currentTime: Date
    
    init(time: Date = Date()) {
        self.currentTime = time
    }
    
    func now() -> Date {
        currentTime
    }
    
    mutating func advance(by interval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(interval)
    }
    
    mutating func set(to time: Date) {
        currentTime = time
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/ViewModels/AlarmListViewModel.swift

```swift
//
//  AlarmListViewModel.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/21/25.
//
import Foundation
import SwiftUI

@MainActor
class AlarmListViewModel: ObservableObject {
  @Published var errorMessage: String?
  @Published var alarms: [Alarm] = []
  @Published var notificationPermissionDetails: NotificationPermissionDetails?
  @Published var showPermissionBlocking = false
  @Published var showMediaVolumeWarning = false

  private let storage: PersistenceStore
  private let permissionService: PermissionServiceProtocol
  private let alarmScheduler: AlarmScheduling
  private let refresher: RefreshRequesting
  private let systemVolumeProvider: SystemVolumeProviding
  private let notificationService: AlarmScheduling  // Keep for test methods only

  init(
    storage: PersistenceStore,
    permissionService: PermissionServiceProtocol,
    alarmScheduler: AlarmScheduling,
    refresher: RefreshRequesting,
    systemVolumeProvider: SystemVolumeProviding,
    notificationService: AlarmScheduling  // Keep for test methods
  ) {
    self.storage = storage
    self.permissionService = permissionService
    self.alarmScheduler = alarmScheduler
    self.refresher = refresher
    self.systemVolumeProvider = systemVolumeProvider
    self.notificationService = notificationService

    fetchAlarms()
    checkNotificationPermissions()
  }

  func refreshPermission() {
      Task {
          let details = await permissionService.checkNotificationPermission()
          self.notificationPermissionDetails = details
      }
  }


  func fetchAlarms() {
    Task {
      do {
        let loadedAlarms = try await storage.loadAlarms()
        await MainActor.run {
          self.alarms = loadedAlarms
          self.errorMessage = nil
        }
      } catch {
        await MainActor.run {
          self.alarms = []
          self.errorMessage = "Could not load alarms"
        }
      }
    }
  }
  
  func checkNotificationPermissions() {
    Task {
      let details = await permissionService.checkNotificationPermission()
      await MainActor.run {
        self.notificationPermissionDetails = details
      }
    }
  }

  func add (_ alarm: Alarm) {
    alarms.append(alarm)
    Task {
      await sync(alarm)
    }
  }

  func toggle(_ alarm:Alarm) {
    guard let thisAlarm = alarms.firstIndex(where: {$0.id == alarm.id}) else { return }

    // Data model guardrail: Don't allow enabling alarms without expectedQR (QR-only MVP)
    if !alarm.isEnabled && alarm.expectedQR == nil {
      errorMessage = "Cannot enable alarm: QR code required for dismissal"
      return
    }

    // Check media volume before enabling alarm
    if !alarm.isEnabled {
      checkMediaVolumeBeforeArming()
    }

    alarms[thisAlarm].isEnabled.toggle()
    Task {
      await sync(alarms[thisAlarm])
    }
  }



  func update(_ alarm: Alarm) {
    guard let thisAlarm = alarms.firstIndex(where: {$0.id == alarm.id}) else { return }
    alarms[thisAlarm] = alarm
    Task {
      await sync(alarm)
    }
  }

  func delete(_ alarm: Alarm) {
    alarms.removeAll{ $0.id == alarm.id}
    Task {
      await sync(alarm)
    }
  }

  private func sync(_ alarm: Alarm) async {
    do {
      try await storage.saveAlarms(alarms)

      // Handle scheduling based on enabled state using unified scheduler
      if !alarm.isEnabled {
        // Cancel alarm when disabling
        await alarmScheduler.cancel(alarmId: alarm.id)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Cancelled (disabled)")
      } else {
        // Schedule alarm when enabling/adding
        // AlarmScheduling.schedule() is always immediate (no separate "immediate" method)
        _ = try await alarmScheduler.schedule(alarm: alarm)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Scheduled")
      }

      // Still trigger refresh for other alarms (non-blocking, best-effort)
      // This handles any other alarms that might need reconciliation
      Task.detached { [weak self] in
        guard let self = self else { return }
        await self.refresher.requestRefresh(alarms: self.alarms)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Background refresh triggered")
      }

      await MainActor.run {
        self.errorMessage = nil
        self.checkNotificationPermissions() // Refresh permission status
      }
    } catch {
      await MainActor.run {
        // Handle specific scheduling errors with appropriate messaging
        if let schedulingError = error as? AlarmSchedulingError {
          switch schedulingError {
          case .systemLimitExceeded:
            // Provide helpful guidance for system limit
            self.errorMessage = "Too many alarms scheduled. Please disable some alarms to add more (iOS limit: 64 notifications)."
          case .permissionDenied:
            self.errorMessage = schedulingError.description
            self.showPermissionBlocking = true
          case .schedulingFailed:
            self.errorMessage = schedulingError.description
          case .invalidConfiguration:
            self.errorMessage = schedulingError.description
          case .notAuthorized:
            self.errorMessage = "AlarmKit permission not granted"
            self.showPermissionBlocking = true
          case .alarmNotFound:
            self.errorMessage = "Alarm not found in system"
          case .ambiguousAlarmState:
            self.errorMessage = "Multiple alarms alerting - cannot determine which to stop"
          case .alreadyHandledBySystem:
            self.errorMessage = "Alarm was already handled by system"
          }
        } else {
          self.errorMessage = "Could not update alarm"
        }
      }
    }
  }
  
  func refreshAllAlarms() async {
    // Use refresher which knows how to use the correct scheduler
    await refresher.requestRefresh(alarms: alarms)
    checkNotificationPermissions()
  }
  
  func handlePermissionGranted() {
    showPermissionBlocking = false
    checkNotificationPermissions()
    
    // Re-sync all enabled alarms
    Task {
      await refreshAllAlarms()
    }
  }

  func ensureNotificationPermissionIfNeeded() {
      Task {
          let details = await permissionService.checkNotificationPermission()
          switch details.authorizationStatus {
          case .notDetermined:
              // show your blocker (or directly request)
              self.showPermissionBlocking = true
          case .denied:
              // keep inline warning; allow Open Settings
              break
          case .authorized:
              break
          }
      }
  }

  // MARK: - Volume Warning

  /// Checks media volume and shows warning if below threshold
  private func checkMediaVolumeBeforeArming() {
    let currentVolume = systemVolumeProvider.currentMediaVolume()

    if currentVolume < AudioUXPolicy.lowMediaVolumeThreshold {
      showMediaVolumeWarning = true
    } else {
      showMediaVolumeWarning = false
    }
  }

  /// Schedules a one-off test alarm to verify lock-screen sound volume
  func testLockScreen() {
    Task {
      do {
        try await notificationService.scheduleOneOffTestAlarm(
          leadTime: AudioUXPolicy.testLeadSeconds
        )
        print("✅ Lock-screen test alarm scheduled (fires in \(Int(AudioUXPolicy.testLeadSeconds))s)")
      } catch {
        errorMessage = "Failed to schedule test alarm: \(error.localizedDescription)"
      }
    }
  }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/ViewModels/DismissalFlowViewModel.swift

```swift
//
//  DismissalFlowViewModel.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  MVP1 QR-only enforced dismissal flow
//  Architecture: Views → ViewModels → Domain → Infrastructure
//

import SwiftUI
import Combine
import AVFoundation

@MainActor
final class DismissalFlowViewModel: ObservableObject {
    
    // MARK: - State Machine

    enum State: Equatable {
        case idle
        case ringing
        case scanning
        case validating
        case success
        case failed(FailureReason)

        var canRetry: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    // MARK: - Phase for AlarmKit integration

    enum Phase: Equatable {
        case awaitingChallenge
        case validating
        case stopping
        case snoozing
        case success
        case failed(String?)
    }
    
    enum FailureReason: Equatable {
        case qrMismatch
        case scanningError
        case permissionDenied
        case noExpectedQR
        case alarmNotFound
        case multipleAlarmsAlerting
        case alarmEndedButChallengesIncomplete  // System auto-dismissed; challenges incomplete

        var displayMessage: String {
            switch self {
            case .qrMismatch:
                return "Invalid QR code. Please try again."
            case .scanningError:
                return "Scanning failed. Please try again."
            case .permissionDenied:
                return "Camera permission required for QR scanning."
            case .noExpectedQR:
                return "No QR code configured for this alarm."
            case .alarmNotFound:
                return "Alarm not found."
            case .multipleAlarmsAlerting:
                return "Multiple alarms detected. Please try again."
            case .alarmEndedButChallengesIncomplete:
                return "Alarm ended by system. Please complete challenges before dismissing."
            }
        }
    }
    
    // MARK: - Published State

    @Published var state: State = .idle
    @Published var phase: Phase = .awaitingChallenge
    @Published var challengeProgress: (completed: Int, total: Int) = (0, 0)
    @Published var scanFeedbackMessage: String?
    @Published var isScreenAwake = false

    // MARK: - Computed Properties

    /// Whether the alarm can be stopped (challenges are complete)
    var canStopAlarm: Bool {
        guard let alarm = alarmSnapshot else { return false }

        let challengeState = ChallengeStackState(
            requiredChallenges: alarm.challengeKind,
            completedChallenges: hasCompletedQR ? [.qr] : []
        )

        return stopAllowed.execute(challengeState: challengeState)
    }

    /// Whether snooze is allowed (alarm is ringing, not in failed state)
    var canSnooze: Bool {
        return state == .ringing && !hasCompletedSuccess
    }

    // MARK: - Dependencies (Protocol-based DI)

    private let qrScanning: QRScanning
    private let notificationService: AlarmScheduling  // Keep for legacy cleanup shim
    private let alarmStorage: PersistenceStore
    private let clock: Clock
    private let appRouter: AppRouting
    private let permissionService: PermissionServiceProtocol
    private let reliabilityLogger: ReliabilityLogging
    private let audioEngine: AlarmAudioEngineProtocol
    private let reliabilityModeProvider: ReliabilityModeProvider
    private let dismissedRegistry: DismissedRegistry
    private let settingsService: SettingsServiceProtocol
    private let alarmScheduler: AlarmScheduling  // NEW: Unified scheduler
    private let alarmRunStore: AlarmRunStore  // NEW: Actor-based run persistence
    private let stopAllowed: StopAlarmAllowed.Type  // NEW: Injected use case
    private let snoozeComputer: SnoozeAlarm.Type  // NEW: Injected use case
    private let idleTimerController: IdleTimerControlling  // NEW: UIKit isolation
    
    // MARK: - Private State

    private var alarmSnapshot: Alarm?
    private var currentAlarmRun: AlarmRun?
    private var occurrenceKey: String?  // ISO8601 formatted fireDate for occurrence-scoped cancellation
    private var scanTask: Task<Void, Never>?
    private var lastSuccessPayload: String?
    private var lastSuccessTime: Date?
    private var hasCompletedSuccess = false
    private var hasCompletedQR = false  // Track QR completion for MVP
    private var intentAlarmId: UUID?  // Optional ID from firing intent (for pre-migration alarms)
    
    // Atomic transition guards
    private var isTransitioning = false
    private let transitionQueue = DispatchQueue(label: "dismissal-flow-transitions", qos: .userInteractive)
    
    // MARK: - Callbacks (Separation of Concerns)

    var onStateChange: ((State) -> Void)?
    var onRunLogged: ((AlarmRun) -> Void)?
    var onRequestHaptics: (() -> Void)?
    
    // MARK: - Init

    init(
        qrScanning: QRScanning,
        notificationService: AlarmScheduling,
        alarmStorage: PersistenceStore,
        clock: Clock,
        appRouter: AppRouting,
        permissionService: PermissionServiceProtocol,
        reliabilityLogger: ReliabilityLogging,
        audioEngine: AlarmAudioEngineProtocol,
        reliabilityModeProvider: ReliabilityModeProvider,
        dismissedRegistry: DismissedRegistry,
        settingsService: SettingsServiceProtocol,
        alarmScheduler: AlarmScheduling,
        alarmRunStore: AlarmRunStore,  // NEW: Actor-based run persistence
        idleTimerController: IdleTimerControlling,  // NEW: UIKit isolation
        stopAllowed: StopAlarmAllowed.Type = StopAlarmAllowed.self,
        snoozeComputer: SnoozeAlarm.Type = SnoozeAlarm.self,
        intentAlarmId: UUID? = nil  // Optional ID from firing intent
    ) {
        self.qrScanning = qrScanning
        self.notificationService = notificationService
        self.alarmStorage = alarmStorage
        self.clock = clock
        self.appRouter = appRouter
        self.permissionService = permissionService
        self.reliabilityLogger = reliabilityLogger
        self.audioEngine = audioEngine
        self.reliabilityModeProvider = reliabilityModeProvider
        self.dismissedRegistry = dismissedRegistry
        self.settingsService = settingsService
        self.alarmScheduler = alarmScheduler
        self.alarmRunStore = alarmRunStore  // NEW
        self.idleTimerController = idleTimerController  // NEW
        self.stopAllowed = stopAllowed
        self.snoozeComputer = snoozeComputer
        self.intentAlarmId = intentAlarmId
    }
    
    // MARK: - Public Intents (All Idempotent)

    @MainActor
    func onChallengeUpdate(completed: Int, total: Int) {
        challengeProgress = (completed, total)
    }

    func start(alarmId: UUID) async {
        // Idempotent: ignore if not idle
        guard state == .idle else { return }

        do {
            // Load alarm snapshot once
            let alarm = try await alarmStorage.alarm(with: alarmId)
            alarmSnapshot = alarm
            
            // Create run record
            let firedAt = clock.now()
            currentAlarmRun = AlarmRun(
                id: UUID(),
                alarmId: alarmId,
                firedAt: firedAt,
                dismissedAt: nil as Date?,
                outcome: .failed // Default to fail; only change on explicit success
            )

            // Generate occurrence key for occurrence-scoped cancellation
            occurrenceKey = OccurrenceKeyFormatter.key(from: firedAt)
            
            // Transition to ringing
            setState(.ringing)

            // Request UI effects
            isScreenAwake = true
            idleTimerController.setIdleTimer(disabled: true)
            onRequestHaptics?()

            // Start alarm sound - check reliability mode first
            let currentMode = reliabilityModeProvider.currentMode
            print("DismissalFlow: Starting alarm with reliability mode: \(currentMode.rawValue)")

            // CRITICAL: In foreground, app audio ALWAYS plays (owns the sound)
            // suppressForegroundSound only affects OS notification sounds (handled by NotificationService)
            // This ensures loud foreground audio without double-audio issues
            let isAppActive = UIApplication.shared.applicationState == .active

            if currentMode == .notificationsPlusAudio {
                // Enhanced mode: use background audio engine + notifications
                do {
                    let soundName = alarm.soundName ?? "ringtone1"

                    // Check current engine state and use appropriate method
                    switch audioEngine.currentState {
                    case .prewarming:
                        // Prewarm is active - promote to ringing
                        try audioEngine.promoteToRinging()
                        print("DismissalFlow: Enhanced mode - promoted prewarm to ringing")

                    case .idle:
                        // No prewarm - start foreground alarm playback
                        try audioEngine.playForegroundAlarm(soundName: soundName)
                        print("DismissalFlow: Enhanced mode - started foreground alarm playback")

                    case .ringing:
                        // Already ringing - ignore (idempotent)
                        print("DismissalFlow: Enhanced mode - already ringing, ignoring start request")
                    }
                } catch {
                    print("DismissalFlow: Enhanced mode audio engine failed: \(error)")
                    // Log error but don't have fallback - audioEngine is the single source
                    reliabilityLogger.log(
                        .dismissFailQR,
                        alarmId: alarm.id,
                        details: ["error": "audio_engine_failed", "reason": error.localizedDescription]
                    )
                }
            } else {
                // Standard mode: notifications-only (App Store safe)
                // Use audioEngine for foreground playback (no fallback needed)
                do {
                    let soundName = alarm.soundName ?? "ringtone1"
                    try audioEngine.playForegroundAlarm(soundName: soundName)
                    print("DismissalFlow: Standard mode - started foreground alarm via audioEngine")
                } catch {
                    print("DismissalFlow: Standard mode audio engine failed: \(error)")
                    reliabilityLogger.log(
                        .dismissFailQR,
                        alarmId: alarm.id,
                        details: ["error": "audio_engine_failed", "reason": error.localizedDescription]
                    )
                }
            }
            
        } catch {
            setState(.failed(.alarmNotFound))
        }
    }
    
    func beginScan() {
        // Idempotent: only allow from ringing state
        guard state == .ringing else { return }
        
        guard let alarm = alarmSnapshot else {
            setState(.failed(.alarmNotFound))
            return
        }
        
        // Check if alarm has expected QR
        guard alarm.expectedQR != nil else {
            setState(.failed(.noExpectedQR))
            return
        }
        
        Task {
            // Check camera permission before attempting to scan
            let cameraStatus = permissionService.checkCameraPermission()
            
            switch cameraStatus {
            case .authorized:
                // Permission granted, start scanning
                do {
                    try await qrScanning.startScanning()
                    setState(.scanning)
                    startLongLivedScanTask()
                } catch {
                    setState(.failed(.scanningError))
                }
                
            case .notDetermined:
                // Request permission first
                let requestResult = await permissionService.requestCameraPermission()
                if requestResult == .authorized {
                    // Permission granted after request, start scanning
                    do {
                        try await qrScanning.startScanning()
                        setState(.scanning)
                        startLongLivedScanTask()
                    } catch {
                        setState(.failed(.scanningError))
                    }
                } else {
                    setState(.failed(.permissionDenied))
                }
                
            case .denied:
                // Permission denied, cannot scan
                setState(.failed(.permissionDenied))
            }
        }
    }
    
    func didScan(payload: String) async {
        // Called by scanner stream - handle state transitions
        print("DismissalFlowViewModel: didScan called with payload: \(payload.prefix(20))... (length: \(payload.count))")

        // Atomic guard: prevent processing if transitioning
        guard !isTransitioning else {
            print("DismissalFlowViewModel: Ignoring scan - currently transitioning")
            return
        }
        
        guard state == .scanning else { 
            // Drop payloads while validating or in other states
            print("DismissalFlowViewModel: Ignoring scan - wrong state: \(state)")
            return 
        }
        
        guard let alarm = alarmSnapshot,
              let expectedQR = alarm.expectedQR else {
            setState(.failed(.noExpectedQR))
            return
        }
        
        // Transition to validating (blocks new payloads)
        setState(.validating)
        
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExpected = expectedQR.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedPayload == trimmedExpected {
            // Success - with debounce check
            if shouldProcessSuccessPayload(payload) {
                print("DismissalFlowViewModel: QR code match successful for alarm: \(alarm.id)")
                hasCompletedQR = true
                onChallengeUpdate(completed: 1, total: 1)  // MVP has only QR
                reliabilityLogger.logDismissSuccess(alarm.id, method: "qr", details: ["payload_length": "\(trimmedPayload.count)"])
                await completeSuccess()
            } else {
                // Duplicate within debounce window - return to scanning (with atomic guard)
                print("DismissalFlowViewModel: Duplicate QR scan ignored (debounce)")
                if !isTransitioning {
                    setState(.scanning)
                }
            }
        } else {
            // Mismatch - transient error, return to scanning with atomic guard
            print("DismissalFlowViewModel: QR code mismatch - expected: \(trimmedExpected.prefix(10))..., got: \(trimmedPayload.prefix(10))...")
            reliabilityLogger.logDismissFail(alarm.id, reason: "qr_mismatch", details: [
                "expected_length": "\(trimmedExpected.count)",
                "received_length": "\(trimmedPayload.count)"
            ])
            scanFeedbackMessage = "Invalid QR code. Please try again."
            
            // Brief delay for user feedback, then return to scanning
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                await MainActor.run {
                    // Atomic guard: only transition if not in the middle of another transition
                    if state == .validating && !isTransitioning && !hasCompletedSuccess {
                        scanFeedbackMessage = nil
                        setState(.scanning)
                    }
                }
            }
        }
    }
    
    func cancelScan() {
        // Idempotent: only allow from scanning/validating
        guard state == .scanning || state == .validating else { return }
        
        stopScanTask()
        scanFeedbackMessage = nil
        setState(.ringing)
    }
    
    func completeSuccess() async {
        // State guards at top
        guard state == .validating else { return }
        guard !isTransitioning else { return }

        // Check if challenges are satisfied using injected use case
        let challengeState = ChallengeStackState(
            requiredChallenges: alarmSnapshot?.challengeKind ?? [],
            completedChallenges: hasCompletedQR ? [.qr] : []
        )

        // Use injected stopAllowed, not static
        guard stopAllowed.execute(challengeState: challengeState) else {
            phase = .failed("Complete all challenges first")
            setState(.failed(.noExpectedQR))  // Transition UI on failure
            return
        }

        guard let alarm = alarmSnapshot else {
            phase = .failed("Alarm not found")
            setState(.failed(.alarmNotFound))
            return
        }

        phase = .stopping
        isTransitioning = true

        // Track whether we should stop audio on cleanup
        var shouldStopAppAudio = true

        // ALWAYS-RUN CLEANUP: defer placed immediately after isTransitioning = true
        // Runs on ALL exit paths (success, error, early return after this point)
        defer {
            // Conditionally stop app audio
            // If system handled alarm but challenges incomplete, keep audio playing
            if shouldStopAppAudio {
                audioEngine.stop()
            }

            // Stop UI effects
            idleTimerController.setIdleTimer(disabled: false)
            isScreenAwake = false

            // Stop scanner
            stopScanTask()

            // Clear transitioning flag
            isTransitioning = false
        }

        do {
            // Use AlarmScheduling protocol for stop with optional intent ID
            try await alarmScheduler.stop(alarmId: alarm.id, intentAlarmId: intentAlarmId)

            // SUCCESS PATH: Only set completion flag after stop succeeds
            hasCompletedSuccess = true

            // Clear intent ID after successful use to prevent stale references
            intentAlarmId = nil

            // Legacy cleanup shim (no-op on AlarmKit)
            if let key = occurrenceKey {
                await notificationService.cleanupAfterDismiss(
                    alarmId: alarm.id,
                    occurrenceKey: key
                )
                print("DismissalFlow: Cleaned up occurrence \(key.prefix(10))...")
            }

            // Mark dismissed in registry
            if let key = occurrenceKey {
                await dismissedRegistry.markDismissed(alarmId: alarm.id, occurrenceKey: key)
            }

            // Complete alarm run with success
            if var run = currentAlarmRun {
                run.dismissedAt = clock.now()
                run.outcome = .success

                do {
                    try await alarmRunStore.appendRun(run)  // NEW: async actor call
                    onRunLogged?(run)
                } catch {
                    print("Failed to persist successful alarm run: \(error)")
                }
            }

            // For one-time alarms: disable
            if alarm.repeatDays.isEmpty {
                var updatedAlarm = alarm
                updatedAlarm.isEnabled = false
                try? await alarmStorage.saveAlarms([updatedAlarm])
                print("DismissalFlow: One-time alarm dismissed and disabled")
            }

            reliabilityLogger.log(
                .dismissSuccess,
                alarmId: alarm.id,
                details: ["method": "challenges_completed"]
            )

            // Drive UI to success state
            phase = .success
            setState(.success)

            // Direct route back (no unnecessary delay)
            appRouter.backToList()

        } catch {
            // Handle protocol-typed AlarmSchedulingError
            if let schedulingError = error as? AlarmSchedulingError {
                // Structured logging with domain error type
                reliabilityLogger.log(
                    .stopFailed,
                    alarmId: alarm.id,
                    details: [
                        "error": schedulingError.description,
                        "error_type": "\(schedulingError)"
                    ]
                )

                switch schedulingError {
                case .alreadyHandledBySystem:
                    // CRITICAL: System auto-dismissed alarm BUT challenges are INCOMPLETE
                    // Keep app audio playing; user must complete challenges to silence
                    shouldStopAppAudio = false  // Prevent audio stop in defer block
                    print("DismissalFlow: [METRIC] event=alarm_system_handled_challenges_incomplete alarm_id=\(alarm.id) audio_preserved=true")
                    setState(.failed(.alarmEndedButChallengesIncomplete))
                    phase = .failed("System handled alarm but challenges incomplete")

                case .ambiguousAlarmState:
                    // Multiple alarms alerting - safe error for user
                    print("DismissalFlow: [METRIC] event=multiple_alarms_alerting alarm_id=\(alarm.id)")
                    setState(.failed(.multipleAlarmsAlerting))
                    phase = .failed("Multiple alarms detected")

                case .alarmNotFound:
                    // Alarm disappeared (unexpected)
                    print("DismissalFlow: [METRIC] event=alarm_not_found alarm_id=\(alarm.id)")
                    setState(.failed(.alarmNotFound))
                    phase = .failed("Alarm not found")

                default:
                    // Other scheduling errors
                    print("DismissalFlow: [METRIC] event=stop_failed error=\(schedulingError) alarm_id=\(alarm.id)")
                    setState(.failed(.alarmNotFound))
                    phase = .failed("Couldn't stop alarm")
                }
            } else {
                // Generic/unexpected error
                reliabilityLogger.log(
                    .stopFailed,
                    alarmId: alarm.id,
                    details: ["error": error.localizedDescription]
                )
                print("DismissalFlow: [METRIC] event=stop_failed_unexpected error=\(error.localizedDescription) alarm_id=\(alarm.id)")
                setState(.failed(.alarmNotFound))
                phase = .failed("Couldn't stop alarm")
            }

            // hasCompletedSuccess remains false, allowing retry
            // defer handles all cleanup automatically (audio stop, scanner stop, flags cleared)
        }
    }
    
    func abort(reason: String) {
        // UI should block this, but handle if forced

        // Atomic guard: prevent concurrent abort
        guard !hasCompletedSuccess else { return }
        guard !isTransitioning else { return }

        // Stop UI effects
        idleTimerController.setIdleTimer(disabled: false)
        isScreenAwake = false

        // Stop alarm sound
        audioEngine.stop()

        // Stop scanner
        stopScanTask()

        // Log failed run
        if let run = currentAlarmRun {
            Task {
                do {
                    try await alarmRunStore.appendRun(run)  // NEW: async actor call
                    await MainActor.run {
                        onRunLogged?(run)
                    }
                } catch {
                    print("Failed to persist failed alarm run: \(error)")
                }
            }
        }

        // Don't cancel follow-ups - let re-alerting continue

        appRouter.backToList()
    }
    
    @MainActor
    func stopAlarm() async {
        // Explicit stop action (same as completeSuccess, but can be called directly)
        await completeSuccess()
    }

    @MainActor
    func snooze(requestedDuration: TimeInterval = 300) async {
        guard let alarm = alarmSnapshot else { return }
        guard !hasCompletedSuccess else { return }
        guard !isTransitioning else { return }

        phase = .snoozing

        // Use injected snoozeComputer, not static
        let nextFireTime = snoozeComputer.execute(
            alarm: alarm,
            now: clock.now(),  // Use injected clock
            requestedSnooze: requestedDuration,
            bounds: SnoozeBounds.default  // From Domain
        )

        let duration = max(1, nextFireTime.timeIntervalSince(clock.now()))

        do {
            // Use AlarmScheduling for countdown/snooze
            try await alarmScheduler.transitionToCountdown(
                alarmId: alarm.id,
                duration: duration
            )

            // Stop current ringing
            audioEngine.stop()

            // Stop UI effects
            idleTimerController.setIdleTimer(disabled: false)
            isScreenAwake = false

            // Stop scanner
            stopScanTask()

            reliabilityLogger.log(
                .snoozeSet,
                alarmId: alarm.id,
                details: ["duration": "\(Int(duration))"]
            )

            appRouter.backToList()
        } catch {
            reliabilityLogger.log(
                .snoozeFailed,
                alarmId: alarm.id,
                details: ["error": error.localizedDescription]
            )
            phase = .failed("Couldn't snooze")
        }
    }
    
    func retry() {
        guard state.canRetry else { return }

        // Reset all completion flags to allow new attempt
        hasCompletedSuccess = false
        hasCompletedQR = false

        // Clear any stale feedback
        scanFeedbackMessage = nil

        // Reset to ringing state
        setState(.ringing)
    }
    
    // MARK: - Private Methods
    
    private func setState(_ newState: State) {
        state = newState
        onStateChange?(newState)
        print("DismissalFlow: \(newState)")
    }
    
    private func startLongLivedScanTask() {
        scanTask = Task {
            do {
                for await payload in qrScanning.scanResultStream() {
                    await didScan(payload: payload)
                }
            } catch {
                await MainActor.run {
                    if state == .scanning {
                        setState(.failed(.scanningError))
                    }
                }
            }
        }
    }
    
    private func stopScanTask() {
        scanTask?.cancel()
        scanTask = nil
        qrScanning.stopScanning()
    }
    
    private func shouldProcessSuccessPayload(_ payload: String) -> Bool {
        // Debounce identical payloads within 300ms
        let now = clock.now()
        
        if let lastPayload = lastSuccessPayload,
           let lastTime = lastSuccessTime,
           lastPayload == payload,
           now.timeIntervalSince(lastTime) < 0.3 {
            return false // Duplicate within debounce window
        }
        
        lastSuccessPayload = payload
        lastSuccessTime = now
        return true
    }
  func cleanup() {
    stopScanTask()

    idleTimerController.setIdleTimer(disabled: false)
    isScreenAwake = false
    scanFeedbackMessage = nil

    // Stop alarm sound
    audioEngine.stop()
  }

    deinit {
      scanTask?.cancel()
      qrScanning.stopScanning()
    }
}

// MARK: - Protocol Definitions

protocol QRScanning {
    func startScanning() async throws
    func stopScanning()
    func scanResultStream() -> AsyncStream<String>
}

public protocol Clock {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Views/RingingView.swift

```swift
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
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/ViewModels/ActiveAlarmDetector.swift

```swift
//
//  ActiveAlarmDetector.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Detects active alarms from delivered notifications and routes to dismissal flow
//

import Foundation

/// Detects if any alarm is currently active (firing) based on delivered notifications
/// Uses protocol-based dependencies for testability
@MainActor
public final class ActiveAlarmDetector {
    private let deliveredNotificationsReader: DeliveredNotificationsReading
    private let activeAlarmPolicy: ActiveAlarmPolicyProviding
    private let dismissedRegistry: DismissedRegistry
    private let alarmStorage: PersistenceStore

    init(
        deliveredNotificationsReader: DeliveredNotificationsReading,
        activeAlarmPolicy: ActiveAlarmPolicyProviding,
        dismissedRegistry: DismissedRegistry,
        alarmStorage: PersistenceStore
    ) {
        self.deliveredNotificationsReader = deliveredNotificationsReader
        self.activeAlarmPolicy = activeAlarmPolicy
        self.dismissedRegistry = dismissedRegistry
        self.alarmStorage = alarmStorage
    }

    /// Check for any currently active alarm
    /// Returns (Alarm, OccurrenceKey) if an active alarm is found, nil otherwise
    func checkForActiveAlarm() async -> (Alarm, OccurrenceKey)? {
        let now = Date()

        // Get delivered notifications from the system
        let delivered = await deliveredNotificationsReader.getDeliveredNotifications()

        // Check each delivered notification to see if it's within the active window
        for notification in delivered {
            // Parse the identifier to extract alarm ID and occurrence key
            guard let alarmId = OccurrenceKeyFormatter.parseAlarmId(from: notification.identifier),
                  let occurrenceKey = OccurrenceKeyFormatter.parse(fromIdentifier: notification.identifier) else {
                continue
            }

            // Check if this occurrence has already been dismissed
            let occurrenceKeyString = OccurrenceKeyFormatter.key(from: occurrenceKey.date)
            if dismissedRegistry.isDismissed(alarmId: alarmId, occurrenceKey: occurrenceKeyString) {
                print("🔍 ActiveAlarmDetector: Skipping dismissed occurrence \(notification.identifier.prefix(50))...")
                continue
            }

            // Compute the active window for this occurrence
            let activeWindowSeconds = activeAlarmPolicy.activeWindowSeconds(for: alarmId, occurrenceKey: notification.identifier)
            let occurrenceDate = occurrenceKey.date
            let activeUntil = occurrenceDate.addingTimeInterval(activeWindowSeconds)

            // Check if we're currently within the active window
            if now >= occurrenceDate && now <= activeUntil {
                // Found an active alarm! Load the full alarm object
                do {
                    let alarms = try await alarmStorage.loadAlarms()
                    if let alarm = alarms.first(where: { $0.id == alarmId }) {
                        print("✅ ActiveAlarmDetector: Found active alarm \(alarmId.uuidString.prefix(8)) at occurrence \(occurrenceKeyString)")
                        return (alarm, occurrenceKey)
                    }
                } catch {
                    print("❌ ActiveAlarmDetector: Failed to load alarms: \(error)")
                }
            }
        }

        // No active alarms found
        return nil
    }
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/Domain/Protocols/PersistenceStore.swift

```swift
//
//  PersistenceStore.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/17/25.
//  Protocol for persistent alarm storage with mandatory Actor conformance per CLAUDE.md §5
//

import Foundation

/// Protocol for persistent alarm storage with actor-based concurrency safety.
/// All implementations MUST be actors to prevent data races.
public protocol PersistenceStore: Actor {
  func loadAlarms() throws -> [Alarm]
  func saveAlarms(_ alarm:[Alarm]) throws
}
```

---

## File: /Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew/DI/DependencyContainer.swift

```swift
//
//  DependencyContainer.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/28/25.
//
// MARK: - Privacy Settings Required
// Add these to Info.plist or Project Settings:
// NSCameraUsageDescription: "This app needs camera access to scan QR codes for alarm dismissal. Scanning a QR code is required to turn off your alarm and proves you are awake."
// NSUserNotificationUsageDescription: "This app needs notification permission to deliver reliable alarm notifications that will wake you up at the scheduled time."

import Foundation
import UserNotifications
import UIKit

@MainActor
class DependencyContainer: ObservableObject {
    // MARK: - Services
    let permissionService: PermissionServiceProtocol
    let persistenceService: PersistenceStore
    let alarmRunStore: AlarmRunStore
    let qrScanningService: QRScanning
    let appRouter: AppRouter
    let reliabilityLogger: ReliabilityLogging
    private let soundEngineConcrete: AlarmSoundEngine
    let settingsServiceConcrete: SettingsService
    let alarmIntentBridge: AlarmIntentBridge
    let alarmScheduler: AlarmScheduling
    private let idleTimerControllerConcrete: UIApplicationIdleTimerController

    // MARK: - New Sound System Services
    private let soundCatalogConcrete: SoundCatalog
    private let alarmFactoryConcrete: DefaultAlarmFactory

    // MARK: - Notification Chaining Services
    private let chainSettingsProviderConcrete: DefaultChainSettingsProvider
    private let notificationIndexConcrete: NotificationIndex
    private let chainPolicyConcrete: ChainPolicy
    private let globalLimitGuardConcrete: GlobalLimitGuard
    private let chainedNotificationSchedulerConcrete: ChainedNotificationScheduler
    private let dismissedRegistryConcrete: DismissedRegistry
    private let refreshCoordinatorConcrete: RefreshCoordinator
    private let activeAlarmPolicyConcrete: ActiveAlarmPolicyProvider
    private let deliveredNotificationsReaderConcrete: DeliveredNotificationsReading
    private let activeAlarmDetectorConcrete: ActiveAlarmDetector
    private let systemVolumeProviderConcrete: SystemVolumeProviding

    // Public protocol exposure
    var refreshCoordinator: RefreshCoordinator { refreshCoordinatorConcrete }
    var audioEngine: AlarmAudioEngineProtocol { soundEngineConcrete }
    var settingsService: SettingsServiceProtocol { settingsServiceConcrete }
    var soundCatalog: SoundCatalogProviding { soundCatalogConcrete }
    var alarmFactory: AlarmFactory { alarmFactoryConcrete }
    var chainedNotificationScheduler: ChainedNotificationScheduling { chainedNotificationSchedulerConcrete }
    var chainSettingsProvider: ChainSettingsProviding { chainSettingsProviderConcrete }
    var activeAlarmDetector: ActiveAlarmDetector { activeAlarmDetectorConcrete }
    var systemVolumeProvider: SystemVolumeProviding { systemVolumeProviderConcrete }
    var notificationService: AlarmScheduling { alarmScheduler }  // Expose alarmScheduler as notificationService for legacy code

    init() {
        // CRITICAL INITIALIZATION ORDER: Prevent dependency cycles

        // 1. Create SoundCatalog first (no dependencies)
        self.soundCatalogConcrete = SoundCatalog()

        // 2. Create basic services
        self.permissionService = PermissionService()
        self.reliabilityLogger = LocalReliabilityLogger()
        self.appRouter = AppRouter()

        // 3. Create PersistenceService (will need sound catalog for repairs in future)
        self.persistenceService = PersistenceService()

        // 3.5. Create AlarmRunStore (actor-based, thread-safe)
        self.alarmRunStore = AlarmRunStore()

        // 4. Create AlarmFactory with sound catalog
        self.alarmFactoryConcrete = DefaultAlarmFactory(catalog: soundCatalogConcrete)

        // 5. Create notification chaining services
        self.chainSettingsProviderConcrete = DefaultChainSettingsProvider()
        let chainSettings = chainSettingsProviderConcrete.chainSettings()

        // Validate settings during initialization (fail fast)
        let validationResult = chainSettingsProviderConcrete.validateSettings(chainSettings)
        assert(validationResult.isValid, "Invalid chain settings: \(validationResult.errorReasons.joined(separator: ", "))")

        self.notificationIndexConcrete = NotificationIndex()
        self.chainPolicyConcrete = ChainPolicy(settings: chainSettings)
        self.globalLimitGuardConcrete = GlobalLimitGuard()
        self.dismissedRegistryConcrete = DismissedRegistry()
        self.activeAlarmPolicyConcrete = ActiveAlarmPolicyProvider(chainPolicy: chainPolicyConcrete)
        self.chainedNotificationSchedulerConcrete = ChainedNotificationScheduler(
            soundCatalog: soundCatalogConcrete,
            notificationIndex: notificationIndexConcrete,
            chainPolicy: chainPolicyConcrete,
            globalLimitGuard: globalLimitGuardConcrete
        )

        // 6. Create audio and settings services (needed by NotificationService)
        self.soundEngineConcrete = AlarmSoundEngine.shared
        self.settingsServiceConcrete = SettingsService(audioEngine: soundEngineConcrete)
        soundEngineConcrete.setReliabilityModeProvider(settingsServiceConcrete)

        // 7. Create remaining services (now with all dependencies available)
        self.qrScanningService = QRScanningService(permissionService: permissionService)
        self.idleTimerControllerConcrete = UIApplicationIdleTimerController()

        // 8. Create AlarmScheduler using factory pattern (iOS 26+ only)
        // Note: Uses domain UUIDs directly - no external ID mapping needed
        let presentationBuilder = AlarmPresentationBuilder()
        if #available(iOS 26.0, *) {
            self.alarmScheduler = AlarmSchedulerFactory.make(
                presentationBuilder: presentationBuilder
            )
        } else {
            fatalError("iOS 26+ required for AlarmKit")
        }

        // 9. Create RefreshCoordinator to coalesce refresh requests
        self.refreshCoordinatorConcrete = RefreshCoordinator(notificationService: alarmScheduler)

        // 10. Create ActiveAlarmDetector for auto-routing to dismissal
        self.deliveredNotificationsReaderConcrete = UNDeliveredNotificationsReader()
        self.activeAlarmDetectorConcrete = ActiveAlarmDetector(
            deliveredNotificationsReader: deliveredNotificationsReaderConcrete,
            activeAlarmPolicy: activeAlarmPolicyConcrete,
            dismissedRegistry: dismissedRegistryConcrete,
            alarmStorage: persistenceService
        )

        // 11. Create SystemVolumeProvider (no dependencies)
        self.systemVolumeProviderConcrete = SystemVolumeProvider()

        // 12. Create AlarmIntentBridge (no dependencies, no OS work in init)
        self.alarmIntentBridge = AlarmIntentBridge()

        // 13. Set up policy provider after all services are initialized
        soundEngineConcrete.setPolicyProvider { [weak self] in
            self?.settingsServiceConcrete.audioPolicy ?? AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
        }
    }

    // MARK: - Activation

    /// Activate observability systems (logging, metrics, etc.)
    /// Call this once at app start - idempotent and separate from notifications
    func activateObservability() {
        // Activate reliability logger with proper file protection for lock screen access
        if let logger = reliabilityLogger as? LocalReliabilityLogger {
            logger.activate()
        }
        print("🔄 DependencyContainer: Activated observability systems")
    }

    /// Activate the alarm scheduler if it's AlarmKit-based
    /// Call this after the container is initialized - idempotent
    @MainActor
    func activateAlarmScheduler() async {
        if #available(iOS 26.0, *) {
            if let kitScheduler = alarmScheduler as? AlarmKitScheduler {
                await kitScheduler.activate()
                print("🔄 DependencyContainer: Activated AlarmKit scheduler")
            }
        }
    }

    /// One-time migration: reconcile AlarmKit IDs after removing external ID mapping
    /// Ensures all alarms use domain UUIDs directly
    @MainActor
    func migrateAlarmKitIDsIfNeeded() async {
        if #available(iOS 26.0, *) {
            if let kitScheduler = alarmScheduler as? AlarmKitScheduler {
                let persisted = (try? await persistenceService.loadAlarms()) ?? []
                await kitScheduler.reconcileAlarmsAfterMigration(persisted: persisted)

                // Clean up externalAlarmId from persisted alarms
                let cleaned = persisted.map { alarm -> Alarm in
                    var mutableAlarm = alarm
                    mutableAlarm.externalAlarmId = nil
                    return mutableAlarm
                }

                if cleaned != persisted {
                    do {
                        try await persistenceService.saveAlarms(cleaned)
                        print("🔄 DependencyContainer: Cleared legacy externalAlarmId fields")
                    } catch {
                        print("⚠️ DependencyContainer: Failed to save cleaned alarms: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - ViewModels
    func makeAlarmListViewModel() -> AlarmListViewModel {
        return AlarmListViewModel(
            storage: persistenceService,
            permissionService: permissionService,
            alarmScheduler: alarmScheduler,
            refresher: refreshCoordinatorConcrete,
            systemVolumeProvider: systemVolumeProviderConcrete,
            notificationService: alarmScheduler  // AlarmScheduler conforms to NotificationScheduling
        )
    }
    
    func makeAlarmDetailViewModel(alarm: Alarm? = nil) -> AlarmDetailViewModel {
        let targetAlarm = alarm ?? alarmFactory.makeNewAlarm()
        return AlarmDetailViewModel(alarm: targetAlarm, isNew: alarm == nil)
    }
    
    func makeDismissalFlowViewModel(intentAlarmID: UUID? = nil) -> DismissalFlowViewModel {
        return DismissalFlowViewModel(
            qrScanning: qrScanningService,
            notificationService: alarmScheduler,  // AlarmScheduler conforms to NotificationScheduling
            alarmStorage: persistenceService,
            clock: SystemClock(),
            appRouter: appRouter,
            permissionService: permissionService,
            reliabilityLogger: reliabilityLogger,
            audioEngine: audioEngine,
            reliabilityModeProvider: settingsService,
            dismissedRegistry: dismissedRegistryConcrete,
            settingsService: settingsService,
            alarmScheduler: alarmScheduler,
            alarmRunStore: alarmRunStore,  // NEW: Inject actor-based run store
            idleTimerController: idleTimerControllerConcrete,  // NEW: UIKit isolation
            stopAllowed: StopAlarmAllowed.self,
            snoozeComputer: SnoozeAlarm.self,
            intentAlarmId: intentAlarmID  // Pass the intent-provided alarm ID
        )
    }
}
```

---

