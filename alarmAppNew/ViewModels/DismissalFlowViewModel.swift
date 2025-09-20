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
    
    enum FailureReason: Equatable {
        case qrMismatch
        case scanningError
        case permissionDenied
        case noExpectedQR
        case alarmNotFound
        
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
            }
        }
    }
    
    // MARK: - Published State
    
    @Published var state: State = .idle
    @Published var scanFeedbackMessage: String?
    @Published var isScreenAwake = false
    
    // MARK: - Dependencies (Protocol-based DI)

    private let qrScanning: QRScanning
    private let notificationService: NotificationScheduling
    private let alarmStorage: AlarmStorage
    private let clock: Clock
    private let appRouter: AppRouter
    private let permissionService: PermissionServiceProtocol
    private let reliabilityLogger: ReliabilityLogging
    private let audioService: AudioServiceProtocol
    
    // MARK: - Private State
    
    private var alarmSnapshot: Alarm?
    private var currentAlarmRun: AlarmRun?
    private var scanTask: Task<Void, Never>?
    private var lastSuccessPayload: String?
    private var lastSuccessTime: Date?
    private var hasCompletedSuccess = false
    
    // Atomic transition guards
    private var isTransitioning = false
    private let transitionQueue = DispatchQueue(label: "dismissal-flow-transitions", qos: .userInteractive)
    
    // MARK: - Callbacks (Separation of Concerns)
    
    var onStateChange: ((State) -> Void)?
    var onRunLogged: ((AlarmRun) -> Void)?
    var onRequestScreenAwake: ((Bool) -> Void)?
    var onRequestAudioControl: ((Bool) -> Void)?
    var onRequestHaptics: (() -> Void)?
    
    // MARK: - Init
    
    init(
        qrScanning: QRScanning,
        notificationService: NotificationScheduling,
        alarmStorage: AlarmStorage,
        clock: Clock,
        appRouter: AppRouter,
        permissionService: PermissionServiceProtocol,
        reliabilityLogger: ReliabilityLogging,
        audioService: AudioServiceProtocol
    ) {
        self.qrScanning = qrScanning
        self.notificationService = notificationService
        self.alarmStorage = alarmStorage
        self.clock = clock
        self.appRouter = appRouter
        self.permissionService = permissionService
        self.reliabilityLogger = reliabilityLogger
        self.audioService = audioService
    }
    
    // MARK: - Public Intents (All Idempotent)
    
    func start(alarmId: UUID) {
        // Idempotent: ignore if not idle
        guard state == .idle else { return }
        
        do {
            // Load alarm snapshot once
            let alarm = try alarmStorage.alarm(with: alarmId)
            alarmSnapshot = alarm
            
            // Create run record
            currentAlarmRun = AlarmRun(
                id: UUID(),
                alarmId: alarmId,
                firedAt: clock.now(),
                dismissedAt: nil as Date?,
                outcome: .failed // Default to fail; only change on explicit success
            )
            
            // Transition to ringing
            setState(.ringing)
            
            // Request UI effects
            isScreenAwake = true
            onRequestScreenAwake?(true)
            onRequestHaptics?()

            // Start alarm sound
            Task {
                await audioService.startRinging(
                    soundName: alarm.soundName,
                    volume: alarm.volume,
                    loop: true
                )
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
    
    func didScan(payload: String) {
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
                reliabilityLogger.logDismissSuccess(alarm.id, method: "qr", details: ["payload_length": "\(trimmedPayload.count)"])
                completeSuccess()
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
    
    func completeSuccess() {
        // Atomic transition guard: prevent concurrent completion
        guard !isTransitioning else { return }
        isTransitioning = true
        
        // Idempotent: only complete once
        guard !hasCompletedSuccess else {
            isTransitioning = false
            return
        }
        guard let alarm = alarmSnapshot else {
            isTransitioning = false
            return
        }
        
        hasCompletedSuccess = true
        
        // Stop UI effects immediately
        onRequestScreenAwake?(false)
        isScreenAwake = false

        // Stop alarm sound
        audioService.stopAndDeactivateSession()

        // Stop scanner
        stopScanTask()

        // Cancel all pending notifications for this alarm
        notificationService.cancelSpecificNotifications(
            for: alarm.id,
            types: [.nudge1, .nudge2, .nudge3]
        )
        
        // Complete alarm run with success
        if var run = currentAlarmRun {
            run.dismissedAt = clock.now()
            run.outcome = .success
            
            do {
                try alarmStorage.appendRun(run)
                onRunLogged?(run)
            } catch {
                print("Failed to persist successful alarm run: \(error)")
            }
        }
        
        // Transition to success
        setState(.success)
        isTransitioning = false
        
        // Brief dwell, then route back
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await MainActor.run {
                // Final guard before navigation
                guard state == .success else { return }
                appRouter.backToList()
            }
        }
    }
    
    func abort(reason: String) {
        // UI should block this, but handle if forced

        // Atomic guard: prevent concurrent abort
        guard !hasCompletedSuccess else { return }
        guard !isTransitioning else { return }

        // Stop UI effects
        onRequestScreenAwake?(false)
        isScreenAwake = false

        // Stop alarm sound
        audioService.stopAndDeactivateSession()

        // Stop scanner
        stopScanTask()
        
        // Log failed run
        if let run = currentAlarmRun {
            do {
                try alarmStorage.appendRun(run) // Already defaults to .fail
                onRunLogged?(run)
            } catch {
                print("Failed to persist failed alarm run: \(error)")
            }
        }
        
        // Don't cancel follow-ups - let re-alerting continue
        
        appRouter.backToList()
    }
    
    func snooze() {
        guard let alarm = alarmSnapshot else { return }
        
        // Atomic guard: prevent concurrent snooze
        guard !hasCompletedSuccess else { return }
        guard !isTransitioning else { return }
        
        // Stop UI effects
        onRequestScreenAwake?(false)
        isScreenAwake = false

        // Stop alarm sound
        audioService.stopAndDeactivateSession()

        // Stop scanner
        stopScanTask()

        // Cancel current notifications and schedule snooze
        Task {
            // Cancel nudges but keep main alarm pattern for snooze
            notificationService.cancelSpecificNotifications(
                for: alarm.id,
                types: [.nudge1, .nudge2, .nudge3]
            )

            let snoozeTime = clock.now().addingTimeInterval(5 * 60) // 5 minutes
            var snoozeAlarm = alarm
            snoozeAlarm.time = snoozeTime
            
            do {
                try await notificationService.scheduleAlarm(snoozeAlarm)
            } catch {
                print("Failed to schedule snooze: \(error)")
            }
        }
        
        // Don't append run for snooze in MVP1
        
        appRouter.backToList()
    }
    
    func retry() {
        guard state.canRetry else { return }
        scanFeedbackMessage = nil
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
                    await MainActor.run {
                        didScan(payload: payload)
                    }
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

    onRequestScreenAwake?(false)
    isScreenAwake = false
    scanFeedbackMessage = nil

    // Stop alarm sound
    audioService.stopAndDeactivateSession()
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

protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date {
        Date()
    }
}
