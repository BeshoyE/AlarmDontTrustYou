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
