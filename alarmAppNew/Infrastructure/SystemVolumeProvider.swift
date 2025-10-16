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
