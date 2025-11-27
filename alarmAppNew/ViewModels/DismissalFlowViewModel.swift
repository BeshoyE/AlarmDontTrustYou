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
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                } catch is CancellationError {
                    // Expected: Task cancelled when user dismisses or view disappears
                    print("📋 DismissalFlow: QR feedback delay cancelled (user dismissed or view changed)")
                    return  // Early exit - don't proceed to state transition

                } catch {
                    // Unexpected: Task.sleep should only throw CancellationError
                    print("⚠️ DismissalFlow: Unexpected Task.sleep error: \(error)")
                    // Continue to state transition in this rare case
                }

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

                do {
                    try await alarmStorage.saveAlarms([updatedAlarm])
                    print("✅ DismissalFlow: One-time alarm disabled successfully")

                } catch {
                    // CRITICAL: If save fails, the alarm will fire again tomorrow
                    print("❌ DismissalFlow: CRITICAL - Failed to disable one-time alarm: \(error)")

                    // Log to reliability logger for production monitoring
                    reliabilityLogger.log(
                        .stopFailed,
                        alarmId: alarm.id,
                        details: [
                            "reason": "persistence_failed_on_disable",
                            "error": "\(error)",
                            "context": "one_time_alarm_disable_after_dismiss"
                        ]
                    )

                    // Set failure state and early return - don't proceed to success
                    phase = .failed("Failed to save alarm settings. The alarm may fire again tomorrow.")
                    setState(.failed(.alarmNotFound))  // Reuse closest failure reason

                    // Early return prevents success logging and UI transition
                    return
                }
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
