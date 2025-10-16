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
