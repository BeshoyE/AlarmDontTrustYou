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
