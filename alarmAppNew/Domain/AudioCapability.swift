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
