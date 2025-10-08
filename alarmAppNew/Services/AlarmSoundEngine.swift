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
            throw NSError(
                domain: "AlarmSoundEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start foreground alarm playback"]
            )
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
            throw NSError(
                domain: "AlarmSoundEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start sleep mode audio"]
            )
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
            throw NSError(
                domain: "AlarmSoundEngine",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Critical: Both '\(soundName).caf' and fallback 'ringtone1.caf' not found in bundle"]
            )
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
            throw NSError(
                domain: "AlarmSoundEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "AVAudioPlayer failed to schedule play(atTime:)"]
            )
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
            let error = NSError(
                domain: "AlarmSoundEngine",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "CRITICAL: prewarm.caf not found in Copy Bundle Resources - refusing to prewarm with any fallback"]
            )
            print("🔊 AlarmSoundEngine: ❌ Bundle assert failed: \(error.localizedDescription)")
            print("🔊 AlarmSoundEngine: ❌ Verify prewarm.caf is in Copy Bundle Resources with correct Target Membership")
            throw error
        }

        let prewarmPlayer = try AVAudioPlayer(contentsOf: prewarmURL)
        prewarmPlayer.numberOfLoops = -1  // Infinite loop
        prewarmPlayer.volume = 0.01       // Imperceptible but real audio (~5s sample)
        prewarmPlayer.prepareToPlay()

        guard prewarmPlayer.play() else {
            throw NSError(domain: "AlarmSoundEngine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to start prewarm audio"])
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
                    throw NSError(
                        domain: "AlarmSoundEngine",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Both '\(soundName).\(`extension`)' and fallback 'ringtone1.caf' not found in bundle"]
                    )
                }
                try schedule(soundURL: fallbackURL, fireAt: date)
                print("🔊 AlarmSoundEngine: ✅ Using fallback 'ringtone1.caf' successfully")
                return
            }

            // Even ringtone1 not found - hard failure
            throw NSError(
                domain: "AlarmSoundEngine",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Sound file \(soundName).\(`extension`) not found in bundle"]
            )
        }

        try schedule(soundURL: url, fireAt: date)
        print("🔊 AlarmSoundEngine: ✅ Scheduled with '\(soundName).\(`extension`)' successfully")
    }
}
