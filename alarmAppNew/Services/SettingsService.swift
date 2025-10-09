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
#endif