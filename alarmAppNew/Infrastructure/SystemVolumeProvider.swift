//
//  SystemVolumeProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Infrastructure adapter for reading system volume levels
//

import AVFoundation

/// Protocol for reading system volume levels
protocol SystemVolumeProviding {
    /// Returns the current media volume (0.0–1.0)
    /// Note: This reads AVAudioSession.outputVolume, which is media volume only.
    /// Ringer volume is NOT accessible via public APIs.
    func currentMediaVolume() -> Float
}

/// Concrete implementation using AVAudioSession
@MainActor
final class SystemVolumeProvider: SystemVolumeProviding {
    func currentMediaVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }
}
